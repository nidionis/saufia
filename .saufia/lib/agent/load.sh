agent::load() {
  local name="${1:-default}"
  local dir="$SAUFIA_CTX/agents/$name"
  [[ -d "$dir" ]] || { echo "agent: no '$name'" >&2; return 1; }

  scope::load "$dir"                          # agents/config → … → name/config
  AGENT_SYSTEM="$(prompt::resolve "$dir" || true)"

  AGENT_OPTS="$(jq -n \
    --argjson t "${AGENT_TEMPERATURE:-0.7}" \
    --argjson p "${AGENT_TOP_P:-0.9}" \
    --argjson k "${AGENT_TOP_K:-40}" \
    --argjson n "${AGENT_NUM_PREDICT:-256}" \
    --argjson ms "${AGENT_MIROSTAT:-0}" \
    --argjson sd "${AGENT_SEED:-0}" \
    '{temperature:$t,top_p:$p,top_k:$k,num_predict:$n,mirostat:$ms,seed:$sd}')"
}
