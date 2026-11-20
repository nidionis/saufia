#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${BIN:-/usr/bin}"
SEMANTIC_DIR="${SEMANTIC_DIR:-/var/lib/digest}"

install -d "$BIN_DIR" "$SEMANTIC_DIR" \
  "$HOME/.config/digest" \
  "$HOME/.config/agents" \
  "$SEMANTIC_DIR/.archive"

install -m 0755 "$(dirname "$0")/digest.py" "$BIN_DIR/digest"

if [[ ! -e "$HOME/.config/digest/digest.env" ]]; then
  install -m 0644 /dev/null "$HOME/.config/digest/digest.env"
fi
