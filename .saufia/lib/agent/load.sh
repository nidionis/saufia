# agent::is_agent <dir> — a folder carrying behavior: config, prompt, or script.
agent::is_agent() {
  local d="${1%/}"
  [[ -d "$d" ]] || return 1
  case "$d" in
    */script|*/script/*|*/scripts|*/scripts/*) return 1 ;;
  esac
  [[ -f "$d/config" || -f "$d/prompt" || -f "$d/script" || -d "$d/script" || -d "$d/scripts" ]]
}

# agent::name <dir> — canonical path relative to agents/.
agent::name() { printf '%s\n' "${1%/}" | sed "s|^$SAUFIA_CTX/agents/||"; }

# agent::action_of <dir> — first path component (read, exec, dev, chat, tool, doc).
agent::action_of() {
  local rel
  rel="$(agent::name "$1")"
  printf '%s\n' "${rel%%/*}"
}

# agent::resolve_dir <name> — exact path first, then unique leaf name.
# Ambiguity is a hard error listing every candidate.
agent::resolve_dir() {
  local name="${1#@}" base="$SAUFIA_CTX/agents" dir
  name="${name%/}"
  [[ -n "$name" ]] || return 1

  if agent::is_agent "$base/$name"; then
    printf '%s\n' "$base/$name"
    return 0
  fi

  local -a hits=()
  local rel
  while IFS= read -r -d '' dir; do
    agent::is_agent "$dir" || continue
    rel="${dir#"$base"/}"
    [[ "$rel" == "$name" || "$rel" == */"$name" ]] && hits+=("$dir")
  done < <(find "$base" -mindepth 1 -type d -print0 2>/dev/null | sort -z)

  case ${#hits[@]} in
    1) printf '%s\n' "${hits[0]}"; return 0 ;;
    0) return 1 ;;
    *)
      printf 'agent: ambiguous "%s":\n' "$name" >&2
      printf '  @%s\n' "${hits[@]#"$base"/}" >&2
      return 2
      ;;
  esac
}

# agent::policy <dir> — action folder sets the privilege ceiling.
# read/chat: no edit, no exec. doc: edit under DOC_OUT_DIR only.
# exec/dev: edit+exec (lab by default). tool: edit+exec via own scripts.
agent::policy() {
  local action
  action="$(agent::action_of "$1")"
  AGENT_ACTION="$action"
  case "$action" in
    read|chat)
      AGENT_CAN_EDIT=0
      AGENT_CAN_EXEC=0
      AGENT_ROOT=""
      ;;
    doc)
      AGENT_CAN_EDIT="${AGENT_CAN_EDIT:-1}"
      AGENT_CAN_EXEC=0
      AGENT_ROOT="${AGENT_ROOT:-$DOT_ROOT/${DOC_OUT_DIR:-doc}}"
      ;;
    exec|dev)
      AGENT_CAN_EDIT="${AGENT_CAN_EDIT:-1}"
      AGENT_CAN_EXEC="${AGENT_CAN_EXEC:-1}"
      AGENT_ROOT="${AGENT_ROOT:-${LAB_DIR:-$CONTEXT/.lab}}"
      ;;
    tool)
      AGENT_CAN_EDIT="${AGENT_CAN_EDIT:-1}"
      AGENT_CAN_EXEC="${AGENT_CAN_EXEC:-1}"
      AGENT_SCRIPT_ONLY=1
      AGENT_ROOT="${AGENT_ROOT:-$DOT_ROOT}"
      ;;
    *)
      AGENT_CAN_EDIT=0
      AGENT_CAN_EXEC=0
      AGENT_ROOT=""
      ;;
  esac
  export AGENT_ACTION AGENT_CAN_EDIT AGENT_CAN_EXEC AGENT_SCRIPT_ONLY AGENT_ROOT
}

# agent::load <name> — resolve, source config chain, source agent libs, build opts.
agent::load() {
  local name="${1:-default}" dir
  dir="$(agent::resolve_dir "$name")"
  local rc=$?
  if (( rc != 0 )); then
    (( rc == 2 )) || echo "agent: no '$name'" >&2
    return "$rc"
  fi

  if [[ -z "${AGENT_MODEL_OVERRIDE+x}" ]]; then
    AGENT_MODEL_OVERRIDE="${AGENT_MODEL:-}"
    export AGENT_MODEL_OVERRIDE
  fi

  export AGENT_DIR="$dir"
  export AGENT_NAME
  AGENT_NAME="$(agent::name "$dir")"

  # Reset per-agent state so configs never leak into the next load.
  AGENT_SYSTEM=""
  AGENT_CAN_EDIT=""
  AGENT_CAN_EXEC=""
  AGENT_SCRIPT_ONLY=""
  AGENT_ROOT=""
  AGENT_NO_AI=""
  AGENT_THOUGHT=""
  AGENT_MODEL="${AGENT_MODEL_OVERRIDE:-${RIGHT_SIZE_MODEL:-${MODEL:-qwen3:0.6b}}}"
  unset AGENT_TEMPERATURE AGENT_TOP_P AGENT_TOP_K AGENT_NUM_PREDICT \
        AGENT_MIROSTAT AGENT_SEED

  local _allexport=0
  [[ "$-" == *a* ]] && _allexport=1
  set -a
  scope::load "$dir"
  (( _allexport )) || set +a
  agent::policy "$dir"

  AGENT_SYSTEM="$(prompt::resolve "$dir" 2>/dev/null || true)"

  # Agent-local libraries, ancestors first (doc/lib applies to doc/readme).
  local -a chain=()
  local d="$dir" lib
  while [[ "$d" == "$SAUFIA_CTX/agents"* ]]; do
    chain+=("$d")
    [[ "$d" == "$SAUFIA_CTX/agents" ]] && break
    d="$(dirname "$d")"
  done
  local i
  for (( i=${#chain[@]}-1; i>=0; i-- )); do
    [[ -d "${chain[i]}/lib" ]] || continue
    while IFS= read -r -d '' lib; do
      source "$lib" 2>/dev/null || true
    done < <(find "${chain[i]}/lib" -type f -name '*.sh' -print0 2>/dev/null | sort -z)
  done

  local opts='{}' key var lc
  for key in TEMPERATURE TOP_P TOP_K NUM_PREDICT MIROSTAT SEED; do
    var="AGENT_${key}"; lc="${key,,}"
    [[ -n "${!var:-}" ]] || continue
    opts="$(jq -n --argjson base "$opts" --argjson v "${!var}" --arg k "$lc" \
      '$base + {($k): $v}')"
  done
  AGENT_OPTS="$opts"
  export AGENT_SYSTEM AGENT_OPTS AGENT_MODEL
}
