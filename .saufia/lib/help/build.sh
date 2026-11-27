help::context() {
  local NAME OUT=""
  OUT+=$'AGENTS (folder = action or agent; behavior = config, prompt, or script)\n'
  while IFS= read -r NAME; do OUT+="$(agent::show "$NAME")"$'\n'
  done < <(agent::list "${1:-$CONTEXT/agents}")
  printf '%s\n' "$OUT"
}
help::verbs() { verb::list; }
help::print() {
  local PROG="${PROG:-saufia}" NAME DESC TYPE
  printf '# %s\n\n' "$PROG"
  printf 'CONTEXT=%s\nDOT_ROOT=%s\n\n' "$CONTEXT" "$DOT_ROOT"
  printf '## Agents\n\n'
  while IFS= read -r NAME; do
    local DIR
    DIR="$(agent::resolve_dir "$NAME")" || continue
    if [[ -x "$DIR/scripts/run.sh" || -x "$DIR/script/bin/${DIR##*/}" ]]; then TYPE="script"
    elif grep -q 'AGENT_NO_AI' "$DIR/config" 2>/dev/null; then TYPE="no-ai"
    elif [[ -f "$DIR/prompt" ]]; then TYPE="llm"
    else TYPE="inherits"; fi
    DESC="$(head -1 "$DIR/prompt" 2>/dev/null | cut -c1-70 || true)"
    printf -- '- **%s** — `[%s]` %s\n' "$NAME" "$TYPE" "${DESC:--}"
  done < <(agent::list)
  printf '\n## Usage\n\n```bash\n'
  printf '%s @agent "prompt"      # ask an agent\n' "$PROG"
  printf '%s @agent               # show agent config\n' "$PROG"
  printf '%s verb::name args      # call a verb directly\n' "$PROG"
  printf '%s help                 # this page\n' "$PROG"
  printf '%s help "question"      # ask the helper agent\n\n' "$PROG"
  printf '```\n\n'
  printf '## Verbs (%d)\n\n```bash\n' "$(verb::list | wc -l)"
  verb::list
  printf '```\n'
}
help::ask() {
  local QUESTION="${1:-list all agents}" CONTEXT_BLOCK
  CONTEXT_BLOCK="$(help::context)"
  agent::load "read/lookup/helper"
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    AGENT_SYSTEM="$(prompt::fill "$AGENT_SYSTEM" "$QUESTION")"
    agent::ask "$QUESTION
$CONTEXT_BLOCK"
  else printf '%s\n' "$CONTEXT_BLOCK"; fi
}
