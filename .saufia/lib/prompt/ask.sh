prompt::ask() {
  local INPUT="${1:-}" SYS=""
  [[ -n "${AGENT_SYSTEM:-}" ]] && SYS="$(prompt::fill "$AGENT_SYSTEM" "$INPUT")"
  agent::ask "$INPUT" "$SYS"
}
