git::add()    { local P="${*:-.}"; git add $P; echo "git::add: staged $P"; }
git::commit() { local M="${1:-}"; [[ -n "$M" ]] && git commit -m "$M" || git commit; }
git::push()   { local R="${1:-$GIT_REMOTE}" B="${2:-$(git rev-parse --abbrev-ref HEAD)}"
                git push "$R" "$B"; echo "git::push: $R/$B"; }
git::workflow() { local M="${1:-}" R="${2:-$GIT_REMOTE}"
                  git::add; git::commit "$M"; git::push "$R"; echo "git::workflow: done"; }
git::status() { local B; B="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
                printf 'branch: %s\n' "$B"; git status --short; }
git::log()    { git log $GIT_LOG_FLAGS -n "${1:-30}"; }
git::diff()   { git diff "$@"; }
git::ignore() { [[ $# -eq 0 ]] || { echo "usage: git ignore" >&2; return 1; }
                "${GIT_EDITOR}" + .gitignore; git::add .gitignore && git::commit ".gitignore"; }
git::dispatch() {
  local SUB="${1:-status}"; shift || true
  declare -A REG=( [add]=git::add [commit]=git::commit [push]=git::push
                   [workflow]=git::workflow [status]=git::status [log]=git::log
                   [diff]=git::diff [ignore]=git::ignore )
  local FN="${REG[$SUB]:-}"
  [[ -n "$FN" ]] || { echo "git: unknown sub '$SUB' (have: ${GIT_SUBS[*]})" >&2; return 1; }
  "$FN" "$@"
}
