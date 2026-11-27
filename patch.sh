#!/usr/bin/env bash
# patch.sh — v5: llm::strip_think + agent::ask_if_llm + bot script fixes
# Usage: cd ~/.svr/saufia && bash patch.sh
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$_here/.saufia" ]] || { echo "patch: run from project root" >&2; exit 1; }

PATCHED=0
fix() { printf '  fixed: %s\n' "$1"; PATCHED=$((PATCHED + 1)); }

# ─── 1/4 lib/llm.sh — llm::strip_think was never defined (broke every @agent ask) ─
echo "[1/4] lib/llm.sh — add llm::strip_think"
cat > "$_here/.saufia/lib/llm.sh" <<'SAUFIA_EOF'
# llm::strip_think — strip model reasoning/thinking blocks from LLM answers.
# Reads the answer from stdin, writes the cleaned answer to stdout.
llm::strip_think() {
  awk '
    BEGIN { strip = 0 }
    {
      if (strip) {
        if ($0 ~ /^```/ || $0 ~ /<\/thinking>/) { strip = 0 }
        next
      }
      if ($0 ~ /^```thinking/ || $0 ~ /^<thinking/ || $0 ~ /^\[?thinking/) {
        strip = 1
        if ($0 ~ /<\/thinking>/) { strip = 0 }
        next
      }
      print $0
    }
  '
}
SAUFIA_EOF
fix "lib/llm.sh (llm::strip_think)"

# ─── 2/4 lib/agent/ask.sh — clean agent::ask + agent::ask_if_llm ─────────────
echo "[2/4] lib/agent/ask.sh — un-mangle agent::ask_if_llm"
cat > "$_here/.saufia/lib/agent/ask.sh" <<'SAUFIA_EOF'
#!/usr/bin/bash
agent::ask() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  local run="${AGENT_DIR:-}/scripts/run.sh"
  if [[ -x "$run" ]]; then
    printf '%s\n' "$P" | "$run"; return $?
  fi
  [[ "${S:-}" == NO_AI ]] && return 0
  ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
}
agent::ask_if_llm() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  if [[ "${DOC_USE_LLM:-0}" == "1" ]]; then
    ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
    return 0
  fi
  printf '%s\n' "${S:-$P}"
}
SAUFIA_EOF
fix "lib/agent/ask.sh (agent::ask_if_llm)"

# ─── 3/4 agents/tool/bot/scripts/run.sh — fix _here + chmod +x ──────────────
echo "[3/4] agents/tool/bot/scripts/run.sh — fix _here + chmod +x"
cat > "$_here/.saufia/agents/tool/bot/scripts/run.sh" <<'SAUFIA_EOF'
#!/usr/bin/env bash
# @bot — parse a DEPLOY script, write all files.
# Usage: saufia @bot < deploy.txt
#        saufia @bot deploy.txt
#        saufia @bot --dry < deploy.txt
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_ctx="${SAUFIA_CTX:-$_here/../../}"
_cfg=(); _d="$_here"
while [[ "$_d" != "/" && "$_d" != "$_ctx" ]]; do
  [[ -f "$_d/config" ]] && _cfg+=("$_d/config"); _d="$(dirname "$_d")"
done
[[ -f "$_ctx/config" ]] && _cfg+=("$_ctx/config")
for (( i=${#_cfg[@]}-1; i>=0; i-- )); do source "${_cfg[i]}" 2>/dev/null || true; done

_expand() {
  local t="$1"
  t="${t//\{FILE\}/${_FILE:-}}"
  t="${t//\{SIZE\}/${_SIZE:-}}"
  t="${t//\{COUNT\}/${_COUNT:-}}"
  printf '%s\n' "$t"
}

bot::action() {
  local path="$1" prefix
  for prefix in "${!BOT_VERBS[@]}"; do
    [[ "$path" == "$prefix"* || "$path" == *"/$prefix"* ]] && {
      printf '%s\n' "${BOT_VERBS[$prefix]}"; return 0; }
  done
  printf '%s\n' "${BOT_VERBS[$BOT_DEFAULT_ACTION]}"
}

DRY=0
if [[ "${1:-}" == "--dry" ]]; then DRY=1; shift; fi
if [[ -n "${1:-}" && -f "$1" ]]; then
  INPUT="$(cat "$1")"
elif [[ ! -t 0 ]]; then INPUT="$(cat)"
else _expand "$BOT_MSG_EMPTY" >&2; exit 1; fi

_COUNT=0; _FILE=""; _HEREDOC_TAG=""; _BODY=""

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ $BOT_RE_BLOCK ]]; then
    _FILE="${BASH_REMATCH[1]}"; _SIZE="${BASH_REMATCH[2]}"
    _BODY=""; continue
  fi
  if [[ -n "$_FILE" && -z "$_HEREDOC_TAG" && "$line" =~ $BOT_RE_HEREDOC_START ]]; then
    _HEREDOC_TAG="${line##*<<}"
    continue
  fi
  if [[ -n "$_HEREDOC_TAG" && "$line" == "$_HEREDOC_TAG" ]]; then
    if (( DRY )); then
      _expand "$BOT_MSG_APPLIED"
    else
      mkdir -p "$(dirname "$_FILE")"
      printf '%s\n' "$_BODY" > "$FILE"
      _expand "$BOT_MSG_APPLIED"
    fi
    (( _COUNT++ )) || true
    _HEREDOC_TAG=""; _FILE=""; continue
  fi
  if [[ -n "$_HEREDOC_TAG" ]]; then
    [[ -z "$_BODY" ]] && _BODY="$line" || _BODY+=$'\n'"$line"
  fi
done <<< "$INPUT"

_expand "$BOT_MSG_SUMMARY"
SAUFIA_EOF
chmod +x "$_here/.saufia/agents/tool/bot/scripts/run.sh"
fix "tool/bot script (_here + exec bit)"

# ─── 4/4 syntax check ─────────────────────────────────────────────────────────
echo "[4/4] syntax check"
bash -n "$_here/.saufia/lib/llm.sh"
bash -n "$_here/.saufia/lib/agent/ask.sh"
bash -n "$_here/.saufia/agents/tool/bot/scripts/run.sh"
bash -n "$_here/bin/saufia"
echo "  ok: bash -n clean"

echo
echo "Done. $PATCHED fixes applied."
echo
echo "Test:"
echo "  ollama serve &            # then: ollama pull qwen3:0.6b"
echo "  ./bin/saufia @git status"
echo "  ./bin/saufia @bot test"
