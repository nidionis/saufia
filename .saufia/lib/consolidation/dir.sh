# consolidation::dir
# summarize one directory
consolidation::dir() {
local dir="$1"
local out="$dir/$CONSOLIDATION_DIR"
local content summary
content="$(find "$dir" -maxdepth 1 -type f \
! -name "$CONSOLIDATION_DIR" ! -name ".consolidation" 2>/dev/null \
-exec strings {} + | head -n "${CONSOLIDATION_MAX_LINES:-200}")"
if [[ -z "$content" ]]; then
printf '(empty)\n' > "$out"
return
fi
if [[ "${DOC_USE_LLM:-0}" == "1" ]]; then
summary="$(agent::ask "Summarize in 2 sentences max:
$content")"
else
summary="$(head -3 <<< "$content" | tr '\n' ' ')"
fi
printf '%s\n' "${summary:-empty}" > "$out"
echo " $out"
}
#!/usr/bin/env bash
# migrate-families.sh — reorganize agents into read/ write/ chat/
set -euo pipefail
CTX="${SAUFIA_CTX:?}/agents"
mkdir -p "$CTX/read" "$CTX/write" "$CTX/chat"
# Reading agents (consume context, produce text to stdout/heap)
for a in cold summarize note classer owto listing who why helper man markdown formator ; do
[[ -d "$CTX/$a" ]] && mv "$CTX/$a" "$CTX/read/$a"
done
# Writing agents (produce code/files, mutate state)
for a in coder calculator dev-junior; do
[[ -d "$CTX/$a" ]] && mv "$CTX/$a" "$CTX/write/$a"
done
# Chat agents (interactive, stateful loop)
for a in eliza; do
[[ -d "$CTX/$a" ]] && mv "$CTX/$a" "$CTX/chat/$a"
done
# Positive/pessimistic: judgment agents → read family (they analyze, don't produce)
for a in positive pessimistic; do
[[ -d "$CTX/$a" ]] && mv "$CTX/$a" "$CTX/read/$a"
done
