prompt::fill() {
  local TXT INPUT="${2:-}" KEY GUARD=0
  if [[ -f "$1" ]]; then TXT="$(cat "$1")"; else TXT="$1"; fi
  TXT="${TXT//\{I\}/$INPUT}"
  TXT="${TXT//\{FORBIDDEN\}/$(prompt::forbid)}"
  while [[ "$TXT" =~ \{([A-Z][A-Z0-9_]*)\} ]] && (( GUARD++ < 64 )); do
    KEY="${BASH_REMATCH[1]}"
    TXT="${TXT//"${BASH_REMATCH[0]}"/${!KEY:-}}"
  done
  printf '%s\n' "$TXT"
}

prompt::forbid() {
  local ITEM OUT=""
  for ITEM in "${FORBIDDEN[@]:-}"; do OUT+="No ${ITEM}. "; done
  printf '%s\n' "${OUT% }"
}

# prompt::join <array-name> [numbered|flat]
prompt::join() {
  local -n ARR="$1"; local MODE="${2:-numbered}" ITEM I=1
  for ITEM in "${ARR[@]:-}"; do
    [[ "$MODE" == numbered ]] && printf '%d. %s\n' "$I" "$ITEM" || printf '%s\n' "$ITEM"
    (( I++ ))
  done
}
