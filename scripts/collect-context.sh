#!/bin/bash
# collect-context.sh — Collect repository context for Ollama prompt
# Usage: ./collect-context.sh [--max-files 50] [--max-size 50000] [--output context.md]

set -euo pipefail

# Defaults
MAX_FILES=50
MAX_SIZE=50000
OUTPUT="context.md"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --max-files) MAX_FILES="$2"; shift 2 ;;
    --max-size) MAX_SIZE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "📂 Collecting repository context..."

# Start fresh
> "$OUTPUT"

# 1. Repository structure
echo "## Repository Structure" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
find . -type f -not -path './.git/*' -not -path './node_modules/*' \
  -not -path './.venv/*' -not -path './dist/*' \
  -not -path './__pycache__/*' -not -path './coverage/*' \
  -not -path './vendor/*' -not -path './.next/*' \
  | sort | head -200 >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# 2. Git info (if available)
if git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "## Git Information" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  echo "Current branch: $(git branch --show-current)" >> "$OUTPUT"
  echo "Last commit: $(git log -1 --oneline)" >> "$OUTPUT"
  echo "Total commits: $(git rev-list --count HEAD)" >> "$OUTPUT"
  echo "" >> "$OUTPUT"

  # Git log (last 10)
  echo "### Recent Commits" >> "$OUTPUT"
  echo '```' >> "$OUTPUT"
  git log -10 --oneline --decorate >> "$OUTPUT"
  echo '```' >> "$OUTPUT"
  echo "" >> "$OUTPUT"
fi

# 3. Dependencies (common files)
echo "## Dependencies" >> "$OUTPUT"
echo "" >> "$OUTPUT"
for depfile in "package.json" "requirements.txt" "composer.json" "Cargo.toml" "go.mod" "pom.xml" "Gemfile" "pyproject.toml"; do
  if [[ -f "$depfile" ]]; then
    echo "### $depfile" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    head -50 "$depfile" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    echo "" >> "$OUTPUT"
  fi
done

# 4. Source code files
echo "## Source Code" >> "$OUTPUT"
echo "" >> "$OUTPUT"

count=0
for f in $(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" \
  -o -name "*.jsx" -o -name "*.tsx" -o -name "*.php" -o -name "*.html" \
  -o -name "*.css" -o -name "*.yaml" -o -name "*.yml" \
  -o -name "*.sh" -o -name "*.ps1" -o -name "*.sql" \) \
  -not -path './.git/*' -not -path './node_modules/*' \
  -not -path './.venv/*' -not -path './dist/*' \
  -not -path './__pycache__/*' -not -path './coverage/*' \
  -not -path './vendor/*' -not -path './.next/*' \
  -not -name "*.min.*" -not -name "*.lock" \
  | sort | head -"$MAX_FILES"); do
  if [[ -f "$f" ]]; then
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    if [[ "$size" -lt "$MAX_SIZE" ]]; then
      # Remove leading ./
      relpath="${f#./}"
      echo "### $relpath" >> "$OUTPUT"
      echo '```' >> "$OUTPUT"
      cat "$f" >> "$OUTPUT"
      echo '```' >> "$OUTPUT"
      echo "" >> "$OUTPUT"
      count=$((count + 1))
    fi
  fi
done

echo "✅ Context collected: $count files, $(wc -c < "$OUTPUT") bytes"
echo "📝 Saved to $OUTPUT"