# prompt::stack <dir> [question] — append all prompts in dir as context
prompt::stack() {
  local dir="$1" q="${2:-}"
  local ctx=""
  if [[ -f "$dir/prompt" ]]; then
    ctx="$(cat "$dir/prompt")"
  fi
  local f
  for f in "$dir"/*.prompt; do
    [[ -f "$f" ]] && ctx+=$'\n'"$(cat "$f")"
  done
  agent::ask "$ctx
$q"
}
