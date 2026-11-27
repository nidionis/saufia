# agent::make <name> [description]
# Uses coldiest to generate prompt + config for a new agent.
agent::make() {
  local name="$1" desc="${2:-$name}" rel
  [[ -n "$name" ]] || { echo "agent::make: usage: agent::make <name> [desc]" >&2; return 1; }
  rel="$name"; [[ "$rel" == */* ]] || rel="tool/$rel"
  local dir="$CONTEXT/agents/$rel"
  mkdir -p "$dir"

  # Save caller state
  local _m="$AGENT_MODEL" _o="$AGENT_OPTS" _s="$AGENT_SYSTEM" _d="$AGENT_DIR"

  agent::load "read/cold/coldiest" || return 1

  agent::ask "Write a terse system prompt for an agent that: $desc
Output the prompt text only. One or two sentences." > "$dir/prompt"

  agent::ask "For an agent that: $desc
Output exactly 3 lines, KEY=value only.
Allowed keys: AGENT_TEMPERATURE AGENT_TOP_P AGENT_NUM_PREDICT
Use literal numbers only (no variables)." > "$dir/config"

  # Restore caller state
  AGENT_MODEL="$_m" AGENT_OPTS="$_o" AGENT_SYSTEM="$_s" AGENT_DIR="$_d"

  echo "agent::make: created agents/$rel"
}
