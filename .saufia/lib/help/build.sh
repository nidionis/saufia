help::context() {
local NAME OUT=""
OUT+=$'AGENTS (path = folder holding a config file)\n'
while IFS= read -r NAME; do
OUT+="$(agent::show "$NAME")"$'\n'
done < <(agent::list "${1:-$CONTEXT/agents}")
printf '%s\n' "$OUT"
}
help::verbs() { verb::list; }
help::print() {
local PROG="${PROG:-saufia}" NAME DESC
printf '# saufia\n\nCONTEXT=%s\nDOT_ROOT=%s\n\n' "$CONTEXT" "$DOT_ROOT"
printf '## Agents\n\n'
while IFS= read -r NAME; do
DESC="$(head -1 "$CONTEXT/agents/$NAME/prompt" 2>/dev/null | cut -c1-70 || true)"
printf -- '- **%s** — %s\n' "$NAME" "${DESC:--}"
done < <(agent::list)
printf '\n## Verbs\n\n'
printf 'Call any verb through the dispatcher:\n\n'
printf '```text\n'
printf '%s @ [args...]\n' "$PROG"
printf '%s @coder coder::run "fix this" ./src\n' "$PROG"
printf '%s @read read::run README.md\n' "$PROG"
printf '%s @default agent::show coder\n' "$PROG"
printf '%s help # this page\n\n' "$PROG"
printf '# @ is optional — defaults to $SAUFIA_AGENT or "default"\n'
printf '```\n\n'
printf 'Defined verbs:\n\n```bash\n'
help::verbs
printf '```\n'
}
help::ask() {
local QUESTION="${1:-list all agents}" CONTEXT_BLOCK
CONTEXT_BLOCK="$(help::context)"
agent::load "read/helper"
if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
AGENT_SYSTEM="$(prompt::fill "$AGENT_SYSTEM" "$QUESTION")"
agent::ask "$QUESTION
$CONTEXT_BLOCK"
else
printf '%s\n' "$CONTEXT_BLOCK"
fi
}
