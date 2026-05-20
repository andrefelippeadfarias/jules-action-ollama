#!/bin/bash
# invoke-ollama.sh — Call local Ollama API with prompt and context
# Usage: ./invoke-ollama.sh --prompt prompt.txt --model glm-5.1:cloud --output response.md

set -euo pipefail

# Defaults
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${OLLAMA_MODEL:-glm-5.1:cloud}"
TEMPERATURE="${OLLAMA_TEMPERATURE:-0.3}"
MAX_TOKENS="${OLLAMA_MAX_TOKENS:-4096}"
PROMPT_FILE=""
OUTPUT_FILE="ollama_response.md"
CONTEXT_FILE="context.md"

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

# Add repo structure if in a git repo
if git rev-parse --is-inside-work-tree &>/dev/null; then
  echo -e "\n\n## Repository Structure\n" >> "$CONTEXT_FILE"
  find . -type f -not -path './.git/*' -not -path './node_modules/*' \
    -not -path './.venv/*' -not -path './dist/*' \
    -not -path './__pycache__/*' -not -path './coverage/*' \
    | head -100 >> "$CONTEXT_FILE"

  # Add relevant source files (limit to 50, max 50KB each)
  echo -e "\n\n## Source Code\n" >> "$CONTEXT_FILE"
  count=0
  for f in $(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" \
    -o -name "*.jsx" -o -name "*.tsx" -o -name "*.php" -o -name "*.html" \
    -o -name "*.css" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \
    -o -name "*.sh" -o -name "*.ps1" -o -name "*.sql" \) \
    -not -path './.git/*' -not -path './node_modules/*' \
    -not -path './package-lock.json' -not -path './yarn.lock' \
    -not -name "*.min.*" | head -50); do
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

# Escape prompt for JSON
PROMPT_JSON=$(python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' < "$CONTEXT_FILE" | sed 's/^"//;s/"$//')

# Call Ollama API
echo "📡 Calling Ollama API..."
RESPONSE=$(curl -s --max-time 300 "${OLLAMA_URL}/api/generate" -d "{
  \"model\": \"${MODEL}\",
  \"prompt\": \"${PROMPT_JSON}\",
  \"stream\": false,
  \"options\": {
    \"temperature\": ${TEMPERATURE},
    \"num_predict\": ${MAX_TOKENS}
  }
}")

# Check for errors
if echo "$RESPONSE" | python3 -c 'import sys,json; data=json.load(sys.stdin); sys.exit(1 if "error" in data else 0)' 2>/dev/null; then
  echo "✅ Response received"
else
  echo "❌ Error from Ollama:"
  echo "$RESPONSE" | python3 -c 'import sys,json; data=json.load(sys.stdin); print(data.get("error","Unknown error"))' 2>/dev/null || echo "$RESPONSE"
  exit 1
fi

# Extract response text
echo "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["response"])' > "$OUTPUT_FILE"

# Stats
TOKENS=$(echo "$RESPONSE" | python3 -c 'import sys,json; data=json.load(sys.stdin); print(data.get("eval_count","unknown"))' 2>/dev/null || echo "unknown")
DURATION=$(echo "$RESPONSE" | python3 -c 'import sys,json; data=json.load(sys.stdin); print(round(data.get("total_duration",0)/1e9,1))' 2>/dev/null || echo "unknown")

echo "📊 Stats: $TOKENS tokens in ${DURATION}s"
echo "📝 Response saved to $OUTPUT_FILE"