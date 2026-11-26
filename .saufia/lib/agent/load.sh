agent::load() {
  local NAME="${1:-default}"
  local DIR="$CONTEXT/agents/$NAME" PF=""
  [[ -d "$DIR" ]] || { echo "agent::load: no '$NAME'" >&2; return 1; }

  scope::load "$DIR"

  while [[ "$DIR" == "$CONTEXT/agents"* ]]; do
    [[ -f "$DIR/prompt" ]] && { PF="$DIR/prompt"; break; }
    DIR="$(dirname "$DIR")"
  done
  AGENT_SYSTEM="${PF:-}"

  local T="${AGENT_TEMPERATURE:-0.7}"
  local P="${AGENT_TOP_P:-0.9}"
  local K="${AGENT_TOP_K:-40}"
  local N="${AGENT_NUM_PREDICT:-$EXPECTED_TOKENS}"
  local MS="${AGENT_MIROSTAT:-0}"
  local SD="${AGENT_SEED:-0}"

  AGENT_OPTS="$(jq -n \
    --argjson t "$T" --argjson p "$P" --argjson k "$K" \
    --argjson n "$N" --argjson ms "$MS" --argjson sd "$SD" \
    '{temperature:$t,top_p:$p,top_k:$k,num_predict:$n,mirostat:$ms,seed:$sd}')"

  AGENT_MODEL="${AGENT_MODEL:-$MODEL}"
}
