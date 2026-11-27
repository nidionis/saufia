# flow::build_plan <prompt> — ask the architect for a plan. 0 loops.
flow::build_plan() {
  local PROMPT="$1"
  agent::load "tool/flow"
  prompt::ask "Decompose into ordered steps.
Each line: AGENT_NAME|ACTION|CONTEXT_SOURCE. No prose.
Available agents: $(agent::list | tr '\n' ',')
Task: $PROMPT"
}

# flow::step_ctx — join stack + heap + source into one context string. 1 loop.
flow::step_ctx() {
  local SRC="$1" CTX="" C
  for C in "${FLOW_STACK[@]:-}"; do CTX+="$C"$'\n'; done   # single loop
  CTX+="$FLOW_HEAP"
  [[ -n "$SRC" && -f "$SRC" ]] && CTX+=$'\n'"$(cat "$SRC")"
  printf '%s\n' "$CTX"
}

# flow::run_step <AGENT> <ACTION> <SRC> — run one process step. 0 loops.
flow::run_step() {
  local AGENT="$1" ACTION="$2" SRC="$3" CTX RESULT
  agent::load "$AGENT" 2>/dev/null || { echo "flow: '$AGENT' missing" >&2; return 1; }
  CTX="$(flow::step_ctx "$SRC")"
  RESULT="$(agent::ask "$CTX"$'\n'"$ACTION" 2>/dev/null || echo "")"
  flow::accumulate "$RESULT"; flow::push_context "[$AGENT] $RESULT"
  (( FLOW_DEPTH++ )) || true
}

# flow::execute <PLAN_FILE> — iterate plan. 1 loop.
flow::execute() {
  local PLAN="$1" AGENT ACTION SRC
  local -a FLOW_STACK=(); local FLOW_HEAP="" FLOW_DEPTH=0 FLOW_STATE="running"
  while IFS='|' read -r AGENT ACTION SRC; do            # single loop
    [[ -z "$AGENT" || "$AGENT" == \#* ]] && continue
    [[ "$FLOW_STATE" == "halted" ]] && break
    flow::run_step "$AGENT" "$ACTION" "$SRC" || true
  done < "$PLAN"
  flow::resize; printf '%s\n' "$FLOW_HEAP"
}

# flow::decompose <prompt> [dir] — build plan, persist, execute. 0 loops.
flow::decompose() {
  local PROMPT="$1" DIR="${2:-.}" STATE PLAN
  STATE="$(mktemp -d "$CONTEXT/.state/flow.XXXXXX")"
  printf '%s\n' "$PROMPT" > "$STATE/input"
  PLAN="$(flow::build_plan "$PROMPT")"
  printf '%s\n' "$PLAN" > "$STATE/plan"
  echo "flow::decompose: plan at $STATE/plan" >&2
  flow::execute "$STATE/plan"
}
