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
