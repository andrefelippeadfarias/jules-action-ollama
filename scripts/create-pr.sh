#!/bin/bash
# create-pr.sh — Create branch, commit changes, push, and open PR
# Usage: ./create-pr.sh --branch-prefix jules --base main --body response.md

set -euo pipefail

# Defaults
BRANCH_PREFIX="jules"
BASE_BRANCH="main"
BODY_FILE=""
TITLE=""
DRY_RUN=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --branch-prefix) BRANCH_PREFIX="$2"; shift 2 ;;
    --base) BASE_BRANCH="$2"; shift 2 ;;
    --body) BODY_FILE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Generate branch name
BRANCH="${BRANCH_PREFIX}-$(date +%Y%m%d-%H%M%S)"

# Check if there are changes
if git diff --quiet && git diff --staged --quiet; then
  echo "ℹ️ No changes to commit. Skipping PR creation."
  exit 0
fi

# Title from body file if not provided
if [[ -z "$TITLE" ]] && [[ -n "$BODY_FILE" ]] && [[ -f "$BODY_FILE" ]]; then
  TITLE=$(head -1 "$BODY_FILE" | cut -c1-72)
fi
TITLE="${TITLE:-🤖 Auto-fix by Jules-Ollama}"

echo "🔧 Creating PR..."
echo "   Branch: $BRANCH"
echo "   Base: $BASE_BRANCH"
echo "   Title: $TITLE"

if [[ "$DRY_RUN" == true ]]; then
  echo "🏃 Dry run - would create:"
  echo "   git checkout -b $BRANCH"
  echo "   git add -A"
  echo "   git commit -m '🤖 $TITLE'"
  echo "   git push origin $BRANCH"
  echo "   gh pr create --base $BASE_BRANCH --head $BRANCH --title '🤖 $TITLE'"
  git diff --stat
  exit 0
fi

# Create branch
git checkout -b "$BRANCH"

# Stage and commit
git add -A
git commit -m "🤖 ${TITLE}"

# Push
git push origin "$BRANCH"

# Create PR
if [[ -n "$BODY_FILE" ]] && [[ -f "$BODY_FILE" ]]; then
  PR_URL=$(gh pr create \
    --base "$BASE_BRANCH" \
    --head "$BRANCH" \
    --title "🤖 ${TITLE}" \
    --body-file "$BODY_FILE" 2>&1)
else
  PR_URL=$(gh pr create \
    --base "$BASE_BRANCH" \
    --head "$BRANCH" \
    --title "🤖 ${TITLE}" \
    --body "Automated fix by Jules-Ollama agent." 2>&1)
fi

echo "✅ PR created: $PR_URL"
echo "::set-output name=pr_url::$PR_URL"
echo "::set-output name=changes_made::true"