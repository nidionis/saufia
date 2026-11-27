append::write() {
  local FILE="$1" CONTENT="$2" MODE="$3" TMP
  mkdir -p "$(dirname "$FILE")"
  if [[ "$MODE" == prepend ]]; then
    TMP="$(mktemp)"; printf '%s\n' "$CONTENT" > "$TMP"
    [[ -f "$FILE" ]] && cat "$FILE" >> "$TMP"; mv "$TMP" "$FILE"
  elif [[ "$MODE" == overwrite ]]; then
    printf '%s\n' "$CONTENT" > "$FILE"
  else
    printf '%s\n' "$CONTENT" >> "$FILE"
  fi
}
append::resize() {
  local FILE="$1" MAX="$2" SIZE TMP
  (( MAX > 0 )) || return 0
  SIZE="$(wc -c < "$FILE")"; (( SIZE > MAX )) || return 0
  TMP="$(mktemp)"; head -c "$MAX" "$FILE" > "$TMP"; mv "$TMP" "$FILE"
  echo "append::resize: $FILE ($SIZE -> $MAX)"
}
append::run() {
  local FILE="${1:?usage: append <file> [content]}"; shift || true
  local CONTENT MODE="${APPEND_MODE:-append}" MAX="${APPEND_MAX_BYTES:-0}"
  if   [[ $# -gt 0 ]]; then CONTENT="$1"
  elif [[ ! -t 0 ]]; then CONTENT="$(cat)"
  else echo "append::run: no content" >&2; return 1; fi
  if declare -F guard::check_path >/dev/null 2>&1; then
    guard::check_path "$FILE" || return 1
  fi
  append::write "$FILE" "$CONTENT" "$MODE"; append::resize "$FILE" "$MAX"
  echo "append::run: $FILE ($(wc -c < "$FILE") bytes, mode=$MODE)"
}
append::agent() {
  local AGENT="${1:?usage: append::agent <agent> <file> [prompt]}" FILE="${2:?missing file}" P="${3:-}" OUT
  local _root="$AGENT_ROOT" _name="$AGENT_NAME" _action="$AGENT_ACTION"
  local _ce="$AGENT_CAN_EDIT" _cx="$AGENT_CAN_EXEC"
  if declare -F guard::check_path >/dev/null 2>&1; then
    guard::check_path "$FILE" || return 1
  fi
  agent::load "$AGENT" || return 1
  OUT="$(prompt::ask "$P")"
  AGENT_ROOT="$_root" AGENT_NAME="$_name" AGENT_ACTION="$_action"
  AGENT_CAN_EDIT="$_ce" AGENT_CAN_EXEC="$_cx"
  append::run "$FILE" "$OUT"
}
