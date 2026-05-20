#!/bin/bash
# invoke-ollama.sh — Call local Ollama API with prompt and context
# SECURITY: Uses proper JSON serialization (python3/jq), no string interpolation
# Usage: ./invoke-ollama.sh --prompt prompt.txt --model glm-5.1:cloud --output response.md

set -euo pipefail

# Defaults
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${OLLAMA_MODEL:-glm-5.1:cloud}"
TEMPERATURE="${OLLAMA_TEMPERATURE:-0.3}"
MAX_TOKENS="${OLLAMA_MAX_TOKENS:-8192}"
PROMPT_FILE=""
OUTPUT_FILE="ollama_response.md"
CONTEXT_FILE="context.md"
MAX_FILES=50

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --url) OLLAMA_URL="$2"; shift 2 ;;
    --temperature) TEMPERATURE="$2"; shift 2 ;;
    --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROMPT_FILE" ]] || [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: --prompt <file> is required"
  exit 1
fi

echo "🔧 Invoking Ollama..."
echo "   Model: $MODEL"
echo "   URL: $OLLAMA_URL"
echo "   Temperature: $TEMPERATURE"
echo "   Max tokens: $MAX_TOKENS"

# Build context
cat "$PROMPT_FILE" > "$CONTEXT_FILE"

# Add repo structure if in a git repo (EXCLUDE sensitive files)
if git rev-parse --is-inside-work-tree &>/dev/null; then
  echo -e "\n\n## Repository Structure\n" >> "$CONTEXT_FILE"
  find . -type f -not -path './.git/*' -not -path './node_modules/*' \
    -not -path './.venv/*' -not -path './dist/*' \
    -not -path './__pycache__/*' -not -path './coverage/*' \
    -not -path './vendor/*' -not -path './.next/*' \
    -not -name '.env' -not -name '.env.*' \
    -not -name '*.key' -not -name '*.pem' -not -name '*.p12' \
    -not -name '*secret*' -not -name '*credential*' -not -name '*token*' \
    -not -name '*password*' -not -name '*.jks' \
    | head -100 >> "$CONTEXT_FILE"

  # Add relevant source files (EXCLUDE sensitive files)
  echo -e "\n\n## Source Code\n" >> "$CONTEXT_FILE"
  count=0
  for f in $(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" \
    -o -name "*.jsx" -o -name "*.tsx" -o -name "*.php" -o -name "*.html" \
    -o -name "*.css" -o -name "*.yaml" -o -name "*.yml" \
    -o -name "*.sh" -o -name "*.ps1" -o -name "*.sql" \) \
    -not -path './.git/*' -not -path './node_modules/*' \
    -not -path './.venv/*' -not -path './dist/*' \
    -not -path './__pycache__/*' -not -path './coverage/*' \
    -not -path './vendor/*' -not -path './.next/*' \
    -not -name '*.min.*' -not -name '*.lock' \
    -not -name '.env' -not -name '.env.*' \
    -not -name '*.key' -not -name '*.pem' \
    | sort | head -"$MAX_FILES"); do
    if [[ -f "$f" ]]; then
      size=$(wc -c < "$f" 2>/dev/null || echo 0)
      if [[ "$size" -lt 50000 ]]; then
        echo -e "\n### $f\n" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        cat "$f" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        count=$((count + 1))
      fi
    fi
  done
  echo "Included $count source files in context"
fi

# SECURITY: Use python3 for proper JSON serialization (no string injection)
RESPONSE_FILE="${OUTPUT_FILE%.md}_raw.json"

python3 -c "
import json, sys

with open('$CONTEXT_FILE', 'r', encoding='utf-8') as f:
    prompt = f.read()

payload = {
    'model': '$MODEL',
    'prompt': prompt,
    'stream': False,
    'options': {
        'temperature': $TEMPERATURE,
        'num_predict': $MAX_TOKENS
    }
}

with open('${CONTEXT_FILE}.json', 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=False)
" || {
  echo "❌ Failed to serialize JSON payload"
  exit 1
}

# Call Ollama API with proper JSON body and timeout
echo "📡 Calling Ollama API..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" --max-time 600 --connect-timeout 30 \
  "${OLLAMA_URL}/api/generate" \
  -H "Content-Type: application/json" \
  -d @"${CONTEXT_FILE}.json")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "❌ Ollama API returned HTTP $HTTP_CODE"
  cat "$RESPONSE_FILE" 2>/dev/null
  exit 1
fi

# Extract response using python3 (handles both 'response' and 'thinking' fields)
python3 -c "
import json, sys

with open('$RESPONSE_FILE', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Handle GLM thinking mode - use 'response' if populated, else 'thinking'
output = ''
if data.get('response', '').strip():
    output = data['response']
elif data.get('thinking', '').strip():
    output = data['thinking']
else:
    output = json.dumps(data, indent=2)

with open('$OUTPUT_FILE', 'w', encoding='utf-8') as f:
    f.write(output)

print(f'✅ Response received')
print(f'Tokens: {data.get(\"eval_count\", \"unknown\")}')
print(f'Length: {len(output)} chars')
" || {
  echo "❌ Failed to parse Ollama response"
  exit 1
}

# SECURITY: Clean up sensitive files
rm -f "$CONTEXT_FILE" "${CONTEXT_FILE}.json" "$RESPONSE_FILE"
echo "🧹 Cleaned up temporary files"

echo "📝 Response saved to $OUTPUT_FILE"