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
export DOT_ROOT CONTEXT SAUFIA_CTX="$CONTEXT"
export _SAUFIA_INIT_DONE=1
while IFS= read -r -d '' FILE; do
  [[ "$FILE" == "$CONTEXT/lib/init.sh" ]] && continue
  source "$FILE" 2>/dev/null || true
done < <(find "$CONTEXT/lib" -type f -name '*.sh' -print0 2>/dev/null | sort -z)
source "$CONTEXT/config" 2>/dev/null || true
agent::load "${SAUFIA_AGENT:-default}" 2>/dev/null || true
if [[ "${OLLAMA_FIT:-1}" == "1" ]] && declare -F ollama::fit_apply >/dev/null 2>&1; then
  ollama::available "${AGENT_MODEL:-${MODEL:-}}" 2>/dev/null \
    || ollama::fit_apply "${AGENT_MODEL:-${MODEL:-}}" 2>/dev/null || true
fi
