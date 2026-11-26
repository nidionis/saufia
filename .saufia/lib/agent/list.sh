# agent::list [root] — every folder that has config and/or prompt.
agent::list() {
  local ROOT="${1:-$CONTEXT/agents}" DIR
  [[ -d "$ROOT" ]] || return 1
  while IFS= read -r DIR; do
    [[ -f "$DIR/config" || -f "$DIR/prompt" ]] || continue
    printf '%s\n' "${DIR#"$ROOT"/}"
  done < <(find "$ROOT" -mindepth 1 -type d 2>/dev/null | sort)
}

# agent::show <name> — dump config + prompt (pure bash)
agent::show() {
  local NAME="$1" DIR="$CONTEXT/agents/$1"
  [[ -d "$DIR" ]] || { echo "agent::show: no '$NAME'" >&2; return 1; }
  printf '### %s\n' "$NAME"
  [[ -f "$DIR/config" ]] && { printf '```\n'; cat "$DIR/config"; printf '```\n'; }
  [[ -f "$DIR/prompt" ]] && { printf '```\n'; cat "$DIR/prompt"; printf '```\n'; }
}

# agent::tree — indented from path depth
agent::tree() {
  local ROOT="${1:-$CONTEXT/agents}" NAME DEPTH
  agent::list "$ROOT" | while IFS= read -r NAME; do
    DEPTH="$(tr -dc '/' <<< "$NAME" | wc -c)"
    printf '%*s%s\n' $((DEPTH * 2)) '' "${NAME##*/}"
  done
}

agent_list() { agent::list "$@"; }
