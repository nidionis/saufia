# prompt::resolve <dir> — nearest prompt walking up to agents root.
prompt::resolve() {
  local d="$1"
  while [[ "$d" == "$CONTEXT/agents"* ]]; do
    [[ -f "$d/prompt" ]] && { cat "$d/prompt"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}
