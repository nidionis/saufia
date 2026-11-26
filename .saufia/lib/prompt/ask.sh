# prompt::ask <input> — top layer: fill the loaded agent's template
# (system prompt) with scoped vars, then ask. CPU-cheap until here.
prompt::ask() {
  local input="${1:-}"
  local sys=""
  [[ -n "${AGENT_SYSTEM:-}" ]] && sys="$(prompt::fill "$AGENT_SYSTEM" "$input")"
  [[ -n "$sys" ]] && sys+="$(prompt::forbid)"
  agent::ask "$input" "$sys"
}
