# junior::refactor — bash pipeline over the softcoded LAYERS array.
junior::refactor() {
local FILE="$1" CODE LAYER STEP OUT I=1
[[ -f "$FILE" ]] || { echo "junior::refactor: no '$FILE'" >&2; return 1; }
CODE="$(cat "$FILE")"
agent::load "dev/junior"
for LAYER in "${LAYERS[@]}"; do
STEP="$(awk '{print tolower($1)}' <<< "$LAYER" | tr -d ':')"
OUT="$CONTEXT/.state/junior.$(basename "$FILE").$STEP"
printf '%s\n' "$CODE" > "$OUT"
if [[ "${DOC_USE_LLM:-0}" == 1 && -d "$CONTEXT/agents/dev/junior/$STEP" ]];
then
agent::load "dev/junior/$STEP"
prompt::fill "$AGENT_SYSTEM" "$CODE" > "$OUT.prompt"
agent::ask "$(cat "$OUT.prompt")" > "$OUT.next" && CODE="$(cat "$OUT.next")"
fi
printf '[%d] %-12s %s\n' "$I" "$STEP" "$OUT"
(( I++ ))
done
agent::load "dev/junior"
if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
prompt::fill "$AGENT_SYSTEM" "$FILE"
else
printf 'diff a/%s b/%s\n# DOC_USE_LLM=0 — layers staged in %s/.state/\n' \
"$(basename "$FILE")" "$(basename "$FILE")" "$CONTEXT"
fi
}
