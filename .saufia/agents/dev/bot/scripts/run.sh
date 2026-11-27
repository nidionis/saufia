#!/usr/bin/env bash
# @bot — find the closest command from apropos and apply it read-only.
# Usage: saufia @bot "list files"
#        echo "disk space" | saufia @bot
set -uo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_ctx="${SAUFIA_CTX:-$_here/../../..}"
export CONTEXT="$_ctx" SAUFIA_CTX="$_ctx"

[[ -f "$_ctx/config" ]] && source "$_ctx/config"
_cfg=(); _d="$_here"
while [[ "$_d" != "/" && "$_d" != "$_ctx" ]]; do
  [[ -f "$_d/config" ]] && _cfg+=("$_d/config")
  _d="$(dirname "$_d")"
done
[[ -f "$_ctx/agents/config" ]] && _cfg+=("$_ctx/agents/config")
for (( i=${#_cfg[@]}-1; i>=0; i-- )); do source "${_cfg[i]}" 2>/dev/null || true; done

source "$_ctx/lib/guard/check.sh" 2>/dev/null || true

expand() {
  local t="$1"
  t="${t//\{QUERY\}/${QUERY:-}}"
  t="${t//\{CMD\}/${BEST:-}}"
  t="${t//\{DESC\}/${BEST_DESC:-}}"
  printf '%s\n' "$t"
}

QUERY="${*:-}"
if [[ -z "$QUERY" && ! -t 0 ]]; then QUERY="$(cat)"; fi
[[ -n "${QUERY//[[:space:]]/}" ]] || { expand "$BOT_MSG_EMPTY" >&2; exit 1; }

read -r -a TOKENS <<< "$(tr '[:upper:]' '[:lower:]' <<< "$QUERY" | tr -cs '[:alnum:]' ' ')"
read -r -a RAW_TOKENS <<< "$QUERY"

declare -A SEEN=()
CAND=()
add_candidates() {
  local q="$1" line cmd
  [[ -n "$q" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+\([^\)]*\)[[:space:]]+-[[:space:]]*(.*)$ ]] || continue
    cmd="${BASH_REMATCH[1]}"
    [[ -n "${SEEN[$cmd]:-}" ]] && continue
    SEEN[$cmd]=1
    CAND+=("$cmd|${BASH_REMATCH[2]}")
  done < <(apropos -s 1 "$q" 2>/dev/null | head -n "${BOT_MAX_CANDIDATES:-60}")
}

add_candidates "$QUERY"

# Deterministic hints for common natural-language verbs.
add_hint() {
  local t="$1" cmd="${BOT_HINTS[$t]:-}" desc
  [[ -n "$cmd" ]] || return 0
  [[ -n "${SEEN[$cmd]:-}" ]] && return 0
  desc="$(whatis "$cmd" 2>/dev/null | head -1)"
  desc="${desc#* - }"
  SEEN[$cmd]=1
  CAND+=("$cmd|${desc:-hint}")
}
if declare -p BOT_HINTS >/dev/null 2>&1; then
  for t in "${TOKENS[@]}"; do add_hint "$t"; done
fi

for t in "${TOKENS[@]}"; do
  [[ ${#CAND[@]} -ge ${BOT_MAX_CANDIDATES:-60} ]] && break
  add_candidates "$t"
done

BEST=""
BEST_DESC=""
BEST_SCORE=-1
for entry in "${CAND[@]}"; do
  cmd="${entry%%|*}"
  desc="${entry#*|}"
  low="$(tr '[:upper:]' '[:lower:]' <<< "$cmd $desc")"
  score=0
  for t in "${TOKENS[@]}"; do
    [[ -z "$t" ]] && continue
    [[ "$t" == "$cmd" ]] && (( score += 6 ))
    grep -qw -- "$t" <<< "$low" && (( score += 2 ))
    stem="${t%s}"
    [[ "$stem" != "$t" ]] && grep -qw -- "$stem" <<< "$low" && (( score += 1 ))
  done
  for c in "${BOT_ALLOW[@]:-}"; do
    [[ "$cmd" == "$c" ]] && { (( score += 10 )); break; }
  done
  (( score += (12 - ${#cmd}) / 4 ))

  if (( score > BEST_SCORE )) \
     || { (( score == BEST_SCORE )) && (( ${#cmd} < ${#BEST} )); }; then
    BEST="$cmd"
    BEST_DESC="$desc"
    BEST_SCORE="$score"
  fi
done

[[ -n "$BEST" ]] || { expand "$BOT_MSG_NOCMD" >&2; exit 1; }
expand "$BOT_MSG_PICK" >&2

# Build a read-only invocation. No shell evaluation, no redirection.
CMDLINE=()
pattern="${TOKENS[${#TOKENS[@]}-1]:-}"
case "$BEST" in
  man)    CMDLINE=(man "$BEST") ;;
  whatis) CMDLINE=(whatis "$BEST") ;;
  apropos) CMDLINE=(apropos "$QUERY") ;;
  ls)     CMDLINE=(ls -la) ;;
  find)   CMDLINE=(find . -maxdepth 1 -iname "*$pattern*") ;;
  grep|rg) CMDLINE=("$BEST" "$pattern" .) ;;
  pwd|date|df|du|free|uname|id|whoami|ps)
          CMDLINE=("$BEST") ;;
  *)
    path=""
    for t in "${RAW_TOKENS[@]}"; do [[ -e "$t" ]] && { path="$t"; break; }; done
    if [[ -n "$path" ]]; then CMDLINE=("$BEST" "$path")
    else CMDLINE=("$BEST" --help); fi
    ;;
esac

show_man() {
  if command -v col >/dev/null 2>&1; then
    MANPAGER=cat man "$BEST" 2>/dev/null | col -b | head -n 80
  else
    MANPAGER=cat man "$BEST" 2>/dev/null | head -n 80
  fi
}

if declare -F guard::readonly >/dev/null 2>&1; then
  guard::readonly "${CMDLINE[@]}" || {
    expand "$BOT_MSG_FALLBACK" >&2
    show_man
    exit 0
  }
fi

root="${AGENT_ROOT:-$PWD}"
( cd "$root" && timeout "${TIMEOUT:-30}" "${CMDLINE[@]}" )
