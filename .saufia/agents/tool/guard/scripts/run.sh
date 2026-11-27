#!/usr/bin/env bash
# @guard — append/remove guard rules. No LLM.
# Usage:
#   saufia @guard list
#   saufia @guard allow '<regex>'
#   saufia @guard deny  '<regex>'
#   saufia @guard path  '<path>'
#   saufia @guard rm allow|deny|path '<regex>'
#   saufia @guard reset
# Or pipe lines: "allow ^ls\s", "deny rm -rf", "path /etc".
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

RX="${GUARD_RX_DIR:-$_ctx/tools/regexes}"
WL="$RX/whitelist.reg"
BL="$RX/blacklist.reg"
GP="$RX/guard.paths"
mkdir -p "$RX"
touch "$WL" "$BL" "$GP"

usage() {
  cat >&2 <<'EOF'
usage: @guard <list|allow|deny|path|rm|reset> [value]
  allow <regex>       append a read-only allow rule
  deny  <regex>       append a deny rule
  path  <path>        protect a path from writes
  rm <kind> <value>   remove one rule (kind: allow|deny|path)
  reset               truncate all rules (keeps timestamped backups)
EOF
}

valid_re() {
  local rc=0
  printf '' | grep -E -- "$1" >/dev/null 2>&1 || rc=$?
  (( rc == 2 )) && return 1
  return 0
}

add_rule() {
  local file="$1" rx="$2" label="$3"
  [[ -n "$rx" ]] || { echo "guard: empty $label" >&2; return 1; }
  if [[ "$label" != "path" ]]; then
    valid_re "$rx" || { echo "guard: invalid regex: $rx" >&2; return 1; }
  fi
  if grep -qxF -- "$rx" "$file" 2>/dev/null; then
    echo "guard: $label already present: $rx"
    return 0
  fi
  printf '%s\n' "$rx" >> "$file"
  echo "guard: $label += $rx"
}

del_rule() {
  local file="$1" rx="$2" label="$3"
  [[ -f "$file" ]] || return 0
  grep -vxF -- "$rx" "$file" > "$file.tmp" || true
  mv "$file.tmp" "$file"
  echo "guard: $label -= $rx"
}

reset_rules() {
  local stamp f
  stamp="$(date +%s)"
  for f in "$WL" "$BL" "$GP"; do
    [[ -s "$f" ]] && cp "$f" "$f.$stamp.bak"
  done
  : > "$WL"
  : > "$BL"
  : > "$GP"
  echo "guard: reset (backups *.$stamp.bak)"
}

list_rules() {
  local f label
  for f in "$WL" "$BL" "$GP"; do
    case "$f" in
      "$WL") label="allow" ;;
      "$BL") label="deny" ;;
      "$GP") label="path" ;;
    esac
    printf '## %s (%s)\n' "$label" "$f"
    nl -ba "$f" 2>/dev/null || true
  done
}

apply() {
  local verb="$1"; shift || true
  case "$verb" in
    list)  list_rules ;;
    allow) add_rule "$WL" "$*" allow ;;
    deny)  add_rule "$BL" "$*" deny ;;
    path)  add_rule "$GP" "$*" path ;;
    rm)
      local kind="${1:-}"; shift || true
      case "$kind" in
        allow) del_rule "$WL" "$*" allow ;;
        deny)  del_rule "$BL" "$*" deny ;;
        path)  del_rule "$GP" "$*" path ;;
        *) usage; return 1 ;;
      esac
      ;;
    reset) reset_rules ;;
    *) usage; return 1 ;;
  esac
}

if [[ $# -gt 0 ]]; then
  apply "$@"
elif [[ ! -t 0 ]]; then
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue
    verb="${line%% *}"
    rest="${line#"$verb"}"; rest="${rest# }"
    if [[ "$verb" == "rm" ]]; then
      kind="${rest%% *}"
      rx="${rest#"$kind"}"; rx="${rx# }"
      apply rm "$kind" "$rx"
    else
      apply "$verb" "$rest"
    fi
  done
else
  usage
fi
