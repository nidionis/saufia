# saufia bootstrap — self-locating, deterministic, no baked paths.
# Re-entry guard: lib/init.sh lives inside lib/, so the recursive walk
# below would otherwise source it forever (fd exhaustion).
[[ -n "${_SAUFIA_INIT_DONE:-}" ]] && return 0

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
export _SAUFIA_INIT_DONE=1

# Recursive (lib/*/*.sh and lib/*/*/*.sh) but never this file.
# sort gives deterministic order; null-delimited handles spaces.
while IFS= read -r -d '' FILE; do
  [[ "$FILE" == "$CONTEXT/lib/init.sh" ]] && continue
  source "$FILE"
done < <(find "$CONTEXT/lib" -type f -name '*.sh' -print0 2>/dev/null | sort -z)

source "$CONTEXT/config"
agent::load "${SAUFIA_AGENT:-default}"
