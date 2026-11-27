#!/usr/bin/env bash
# @sed — sed edit with git-versioned PR review.
# Usage: saufia @sed <file> "s/old/new/g"
#        echo "s/old/new/g" | saufia @sed <file>
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_ctx="${SAUFIA_CTX:-$_here/../../}"
_cfg=(); _d="$_here"
while [[ "$_d" != "/" && "$_d" != "$_ctx" ]]; do
  [[ -f "$_d/config" ]] && _cfg+=("$_d/config")
  _d="$(dirname "$_d")"
done
[[ -f "$_ctx/config" ]] && _cfg+=("$_ctx/config")
for (( i=${#_cfg[@]}-1; i>=0; i-- )); do source "${_cfg[i]}" 2>/dev/null || true; done

_expand() {
  local t="$1"
  t="${t//\{EXPR\}/${EXPR:-}}"
  t="${t//\{BRANCH\}/${BRANCH:-}}"
  t="${t//\{BASE\}/${BASE:-}}"
  t="${t//\{FILE\}/${FILE:-}}"
  printf '%s\n' "$t"
}

FILE="${1:?usage: @sed <file> [sed-expr]}"; shift || true
EXPR="${1:-$(cat)}"
[[ -f "$FILE" ]] || { _expand "$SED_MSG_NOFILE" >&2; exit 1; }
[[ -n "$EXPR" ]] || { _expand "$SED_MSG_EMPTY" >&2; exit 1; }
if [[ -n "${AGENT_ROOT:-}" ]]; then
  _abs="$(realpath -m -- "$FILE")"; _root="$(realpath -m -- "$AGENT_ROOT")"
  [[ "$_abs" == "$_root" || "$_abs" == "$_root/"* ]] \
    || { echo "sed: DENIED path '$_abs' outside $_root" >&2; exit 1; }
fi

ROOT="$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null)" \
  || { _expand "$SED_MSG_NOTGIT" >&2; exit 1; }

# Safety: refuse to operate on filesystem root
[[ "$ROOT" == "/" ]] && { echo "sed: refusing root" >&2; exit 1; }

FILE_REL="${FILE#"$ROOT"/}"
BASE="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
BRANCH="${SED_BRANCH_PREFIX}/$(date +%s)-${RANDOM}"
TMP="$(mktemp)"; STASHED=0

sed "$EXPR" "$FILE" > "$TMP" || { rm -f "$TMP"; _expand "$SED_MSG_SEDFAIL" >&2; exit 1; }
if diff -q "$FILE" "$TMP" >/dev/null 2>&1; then
  rm -f "$TMP"; _expand "$SED_MSG_NOCHANGE"; exit 0; fi

cd "$ROOT"
git stash push -m "$SED_STASH_MSG" --quiet 2>/dev/null && STASHED=1
git checkout -b "$BRANCH" --quiet
cp "$TMP" "$FILE_REL"; git add "$FILE_REL"
git commit -m "$(_expand "$SED_COMMIT_FMT")" --quiet

_expand "$SED_DIFF_HEADER"
git diff HEAD~1 -- "$FILE_REL"
_expand "$SED_DIFF_FOOTER"

_do_merge() {
  git checkout "$BASE" --quiet
  git merge "$BRANCH" --no-edit --quiet
  git branch -d "$BRANCH" --quiet
  _expand "$SED_MSG_MERGED"
}
_do_keep() {
  git checkout "$BASE" --quiet
  _expand "$SED_MSG_KEPT"
}

read -rp "$(_expand "$SED_PROMPT_MERGE")" R; R="${R,,}"
if   [[ "$R" =~ $SED_RE_YES ]]; then _do_merge
elif [[ "$R" =~ $SED_RE_DIFF ]]; then
  git diff HEAD~1 -- "$FILE_REL" | ${PAGER:-less}
  read -rp "$(_expand "$SED_PROMPT_DIFF")" R2
  [[ "${R2,,}" =~ $SED_RE_YES ]] && _do_merge || _do_keep
elif [[ "$R" =~ $SED_RE_EDIT ]]; then
  ${EDITOR:-vim} "$FILE_REL"; git add "$FILE_REL"; git commit --amend --quiet
  read -rp "$(_expand "$SED_PROMPT_EDIT")" R3
  [[ "${R3,,}" =~ $SED_RE_YES ]] && _do_merge || _do_keep
else _do_keep; fi

[[ $STASHED -eq 1 ]] && git stash pop --quiet 2>/dev/null || true
rm -f "$TMP"
