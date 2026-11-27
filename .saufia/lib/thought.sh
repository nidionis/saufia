# thought::* — per-agent scratchpad under THOUGHT_DIR/<action>/<agent>/.
# Every agent may write here except those with AGENT_THOUGHT=0 (@amnesia).

thought::enabled() { [[ "${AGENT_THOUGHT:-1}" != "0" ]]; }

thought::dir() {
  local name="${AGENT_NAME:-${AGENT_ACTION:-misc}/${AGENT_DIR##*/}}"
  printf '%s/%s\n' "${THOUGHT_DIR:-$CONTEXT/.state/thought}" "$name"
}

thought::write() {
  if ! thought::enabled; then
    echo "thought: DENIED — '${AGENT_NAME:-?}' is amnesic" >&2
    return 1
  fi
  local dir file
  dir="$(thought::dir)"
  file="$dir/notes.md"
  mkdir -p "$dir" || return 1
  {
    printf '\n## %s\n' "$(date -Is)"
    printf '%s\n' "$*"
  } >> "$file" || return 1
  printf '%s\n' "$file"
}

thought::read() {
  local file n="${1:-40}"
  file="$(thought::dir)/notes.md"
  [[ -f "$file" ]] || return 1
  tail -n "$n" "$file"
}

thought::clear() {
  local dir
  dir="$(thought::dir)"
  [[ -d "$dir" ]] || return 0
  rm -f "$dir/notes.md"
  echo "thought: cleared $dir"
}
