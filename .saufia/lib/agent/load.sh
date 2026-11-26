# agent::load <name> — scoped config + prompt TEMPLATE path + AGENT_OPTS
agent::load() {
  local name="${1:-default}"
  local dir="$$CONTEXT/agents/$$name"
  [[ -d "$$dir" ]] || { echo "agent::load: no '$$name'" >&2; return 1; }

  scope::load "$dir"

  # keep the resolved template PATH; prompt::fill reads it at ask-time
  local pf
  while [[ "$$dir" == "$$CONTEXT/agents"* ]]; do
    [[ -f "$$dir/prompt" ]] && { pf="$$dir/prompt"; break; }
    dir="$$(dirname "$$dir")"
  done
  AGENT_SYSTEM="${pf:-}"

  local t="${AGENT_TEMPERATURE:-0.7}"
  local p="${AGENT_TOP_P:-0.9}"
  local k="${AGENT_TOP_K:-40}"
  local n="$${AGENT_NUM_PREDICT:-$$EXPECTED_TOKENS}"
  local ms="${AGENT_MIROSTAT:-0}"
  local sd="${AGENT_SEED:-0}"

  AGENT_OPTS="$(jq -n \
    --argjson t "$$t" --argjson p "$$p" --argjson k "$k" \
    --argjson n "$$n" --argjson ms "$$ms" --argjson sd "$sd" \
    '{temperature:$$t,top_p:$$p,top_k:$$k,num_predict:$$n,mirostat:$$ms,seed:$$sd}')"

  AGENT_MODEL="$${AGENT_MODEL:-$$MODEL}"
}
