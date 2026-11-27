# flow::signals — softcoded signal system. Handlers in a registry. 0 loops.
declare -A FLOW_SIGNALS=(
  [FLOW_INTERRUPT]=flow::halt   [FLOW_CONTINUE]=flow::next
  [FLOW_ESCALATE]=flow::escalate [FLOW_DELEGATE]=flow::delegate
  [FLOW_ACCUMULATE]=flow::accumulate [FLOW_EMIT]=flow::emit
  [FLOW_RESIZE]=flow::resize     [FLOW_STACK]=flow::push_context
  [FLOW_POP]=flow::pop_context )

flow::signal() { local H="${FLOW_SIGNALS[$1]:-}"
  [[ -n "$H" ]] || { echo "flow::signal: unknown '$1'" >&2; return 1; }
  shift; "$H" "$@"; }

flow::halt()        { FLOW_STATE="halted"; echo "flow::halt: depth $FLOW_DEPTH" >&2; }
flow::next()        { FLOW_STATE="running"; (( FLOW_DEPTH++ )) || true; }
flow::escalate()    { FLOW_ESCALATE_TARGET="${1:-default}"; echo "flow::escalate: @$FLOW_ESCALATE_TARGET" >&2; }
flow::delegate()    { FLOW_DELEGATE_TARGET="$1"; shift; FLOW_DELEGATE_ARGS="$*"; echo "flow::delegate: @$FLOW_DELEGATE_TARGET" >&2; }
flow::accumulate()  { FLOW_HEAP+="$1"$'\n'; }
flow::emit()        { printf '%s\n' "$*"; }
flow::resize()      { local M="${FLOW_MAX_HEAP:-0}"; (( M > 0 )) && FLOW_HEAP="$(printf '%s' "$FLOW_HEAP" | head -c "$M")"; }
flow::push_context() { FLOW_STACK+=("$1"); }
flow::pop_context()  { local N=${#FLOW_STACK[@]}; (( N > 0 )) && { echo "${FLOW_STACK[N-1]}"; unset 'FLOW_STACK[N-1]'; }; }
