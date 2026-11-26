# agent::load <name> — resolve scoped config + prompt, build AGENT_OPTS
agent::load() {
  local name="${1:-default}"
  local dir="$SAUFIA_CTX/agents/$name"
  [[ -d "$dir" ]] || { echo "agent::load: no '$name'" >&2; return 1; }

  scope::load "$dir"
  AGENT_SYSTEM="$(prompt::resolve "$dir" || true)"

  # Defaults prevent jq crash on partial configs
  local t="${AGENT_TEMPERATURE:-0.7}"
  local p="${AGENT_TOP_P:-0.9}"
  local k="${AGENT_TOP_K:-40}"
  local n="${AGENT_NUM_PREDICT:-256}"
  local ms="${AGENT_MIROSTAT:-0}"
  local sd="${AGENT_SEED:-0}"

  AGENT_OPTS="$(jq -n \
    --argjson t "$t" \
    --argjson p "$p" \
    --argjson k "$k" \
    --argjson n "$n" \
    --argjson ms "$ms" \
    --argjson sd "$sd" \
    '{temperature:$t,top_p:$p,top_k:$k,num_predict:$n,mirostat:$ms,seed:$sd}')"

  AGENT_MODEL="${AGENT_MODEL:-$MODEL}"
}
