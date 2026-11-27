#!/usr/bin/env bash
# @patch — bump DEPLOY version. Usage: saufia @patch [--check] [file]
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_ctx="${SAUFIA_CTX:-$_here/../../}"
_cfg=(); _d="$_here"
while [[ "$_d" != "/" && "$_d" != "$_ctx" ]]; do
  [[ -f "$_d/config" ]] && _cfg+=("$_d/config"); _d="$(dirname "$_d")"
done
[[ -f "$_ctx/config" ]] && _cfg+=("$_ctx/config")
for (( i=${#_cfg[@]}-1; i>=0; i-- )); do source "${_cfg[i]}" 2>/dev/null || true; done

_expand() {
  local t="$1"
  t="${t//\{OLD\}/${OLD:-}}"
  t="${t//\{NEW\}/${NEW:-}}"
  t="${t//\{FILE\}/${FILE:-}}"
  printf '%s\n' "$t"
}

DRY=0
if [[ "${1:-}" == "--check" ]]; then DRY=1; shift; fi
FILE="${1:-$PATCH_FILE}"
[[ -f "$FILE" ]] || { _expand "$PATCH_MSG_NOFILE" >&2; exit 1; }
if [[ -n "${AGENT_ROOT:-}" ]]; then
  _abs="$(realpath -m -- "$FILE")"; _root="$(realpath -m -- "$AGENT_ROOT")"
  [[ "$_abs" == "$_root" || "$_abs" == "$_root/"* ]] \
    || { echo "patch: DENIED path '$_abs' outside $_root" >&2; exit 1; }
fi

OLD_LINE="$(grep -m1 "$PATCH_PATTERN" "$FILE")" \
  || { _expand "$PATCH_MSG_NOTFOUND" >&2; exit 1; }

OLD_TS="$(awk -F"$PATCH_SEP" '{gsub(/^# DEPLOY . /,"",$1); print $1}' <<< "$OLD_LINE")"
REST="$(awk -F"$PATCH_SEP" 'NR==1{for(i=2;i<=NF;i++) printf "%s%s",$i,(i<NF?" | ":"\n")}' <<< "$OLD_LINE")"
NEW_TS="$(date "$PATCH_DATE_FMT")"
NEW_LINE="# DEPLOY — ${NEW_TS}${PATCH_SEP}${REST}"

if [[ "$OLD_TS" == "$NEW_TS" ]]; then _expand "$PATCH_MSG_SAME"; exit 0; fi
if (( DRY )); then printf 'old: %s\nnew: %s\n' "$OLD_LINE" "$NEW_LINE"; exit 0; fi

TMP="$(mktemp)"
sed "s|^${PATCH_PATTERN}.*|${NEW_LINE}|" "$FILE" > "$TMP"
mv "$TMP" "$FILE"
_expand "$PATCH_MSG_BUMP"
