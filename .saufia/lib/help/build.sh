help::context() {
  local NAME OUT=""
  OUT+=$'AGENTS (path = folder holding config and/or prompt)\n'
  while IFS= read -r NAME; do
    OUT+="$(agent::show "$NAME")"$'\n'
  done < <(agent::list "${1:-$CONTEXT/agents}")
  printf '%s\n' "$OUT"
}

help::print() {
  local NAME DESC
  printf '# saufia\n\nCONTEXT=%s\nDOT_ROOT=%s\n\n## Agents\n\n' "$CONTEXT" "$DOT_ROOT"
  while IFS= read -r NAME; do
    DESC="$(head -1 "$CONTEXT/agents/$NAME/prompt" 2>/dev/null | cut -c1-70 || true)"
    printf -- '- **%s** — %s\n' "$NAME" "${DESC:--}"
  done < <(agent::list)

  printf '\n## Verbs\n\n```bash\n'
  grep -rhoE '^[a-z][a-z0-9_]*::[a-z][a-z0-9_]*$$$$' "$CONTEXT/lib" 2>/dev/null \
    | sed 's/()//' | sort -u || true
  printf '```\n'
}

help::ask() {
  local QUESTION="${1:-list all agents}" CONTEXT_BLOCK
  CONTEXT_BLOCK="$(help::context)"
  agent::load "helper"
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    AGENT_SYSTEM="$(prompt::fill "$AGENT_SYSTEM" "$QUESTION")"
    agent::ask "$QUESTION
$CONTEXT_BLOCK"
  else
    printf '%s\n' "$CONTEXT_BLOCK"
  fi
}
