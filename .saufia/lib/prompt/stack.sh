# prompt::stack <dir> [question] — cumulative prompting:
# every *.prompt in dir (sorted) is appended as context, then asked.
prompt::stack() {
  local dir="$1" q="${2:-}"
  local ctx
  ctx="$(cat "$dir"/*.prompt 2>/dev/null)"
  agent::ask "$ctx
$q"
}
