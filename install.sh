#!/bin/bash
set -e

REPO="subsequence-ai/subtext"
BRANCH="main"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

echo "Installing Subtext..."

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
  echo ""
  echo "Warning: jq is required but not installed."
  echo "  macOS:  brew install jq"
  echo "  Linux:  sudo apt install jq"
  echo ""
  echo "Install jq first, then re-run this script."
  exit 1
fi

# Check for ~/.claude directory
if [ ! -d "$HOME/.claude" ]; then
  echo "Error: ~/.claude directory not found. Is Claude Code installed?"
  exit 1
fi

# Backup existing statusline if present
if [ -f "$DEST" ]; then
  cp "$DEST" "${DEST}.bak"
  echo "Backed up existing statusline to ${DEST}.bak"
fi

# Download statusline.sh
curl -fsSL "${RAW}/statusline.sh" -o "$DEST"
chmod +x "$DEST"
echo "Downloaded statusline.sh to $DEST"

# Add statusLine config to settings.json
if [ -f "$SETTINGS" ]; then
  if echo "$(cat "$SETTINGS")" | jq -e '.statusLine' >/dev/null 2>&1; then
    echo "statusLine already configured in settings.json — skipping."
  else
    tmp=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "Added statusLine config to settings.json"
  fi
else
  echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' | jq '.' > "$SETTINGS"
  echo "Created settings.json with statusLine config"
fi

echo ""
echo "Subtext installed. Changes take effect on your next interaction with Claude Code."
