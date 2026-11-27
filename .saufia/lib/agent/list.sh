# agent::list [root] — every folder that carries behavior.
agent::list() {
  local ROOT="${1:-$CONTEXT/agents}" DIR
  [[ -d "$ROOT" ]] || return 1
  while IFS= read -r -d '' DIR; do
    agent::is_agent "$DIR" || continue
    printf '%s\n' "${DIR#"$ROOT"/}"
  done < <(find "$ROOT" -mindepth 1 -type d -print0 2>/dev/null | sort -z)
}

# agent::leaves [root] — callable agents only (no agent children).
agent::leaves() {
  local ROOT="${1:-$CONTEXT/agents}" DIR CHILD
  [[ -d "$ROOT" ]] || return 1
  while IFS= read -r -d '' DIR; do
    agent::is_agent "$DIR" || continue
    while IFS= read -r -d '' CHILD; do
      agent::is_agent "$CHILD" && continue 2
    done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    printf '%s\n' "${DIR#"$ROOT"/}"
  done < <(find "$ROOT" -mindepth 1 -type d -print0 2>/dev/null | sort -z)
}

# agent::show <name> — dump config + prompt (pure bash, leaf-aware).
agent::show() {
  local NAME="$1" DIR
  DIR="$(agent::resolve_dir "$NAME")" || {
    echo "agent::show: no '$NAME'" >&2
    return 1
  }
  printf '### @%s\n' "$(agent::name "$DIR")"
  [[ -f "$DIR/config" ]] && { printf '```\n'; cat "$DIR/config"; printf '```\n'; }
  [[ -f "$DIR/prompt" ]] && { printf '```\n'; cat "$DIR/prompt"; printf '```\n'; }
}

# agent::tree — indented from path depth.
agent::tree() {
  local ROOT="${1:-$CONTEXT/agents}" NAME DEPTH
  agent::list "$ROOT" | while IFS= read -r NAME; do
    DEPTH="$(tr -dc '/' <<< "$NAME" | wc -c)"
    printf '%*s%s\n' $((DEPTH * 2)) '' "${NAME##*/}"
  done
}

agent_list() { agent::list "$@"; }
