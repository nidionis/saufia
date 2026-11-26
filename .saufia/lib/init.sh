# saufia bootstrap — self-locating, deterministic, no baked paths.
saufia::locate() {
  local DIR="${1:-$PWD}"
  while [[ "$DIR" != "/" ]]; do
    [[ -d "$DIR/.saufia" ]] && { DOT_ROOT="$DIR"; CONTEXT="$DIR/.saufia"; return 0; }
    DIR="$(dirname "$DIR")"
  done
  DOT_ROOT="$PWD"; CONTEXT="$PWD/.saufia"
}

[[ -n "${CONTEXT:-}" ]] || saufia::locate "${1:-$PWD}"
DOT_ROOT="${DOT_ROOT:-$(dirname "$CONTEXT")}"
export DOT_ROOT CONTEXT
export SAUFIA_CTX="$CONTEXT"          # legacy alias — eliza untouched

for FILE in "$CONTEXT"/lib/*/*.sh; do
  [[ -f "$FILE" ]] && source "$FILE"
done

source "$CONTEXT/config"
agent::load "${SAUFIA_AGENT:-default}"
