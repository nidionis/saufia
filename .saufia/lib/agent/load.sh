agent::load() {
  local name="${1:-default}"
  local dir="$SAUFIA_CTX/agents/$name"
  [[ -d "$dir" ]] || { echo "agent: no '$name'" >&2; return 1; }

  scope::load "$dir"                          # agents/config → … → name/config
  AGENT_SYSTEM="$(prompt::resolve "$dir" || true)"

  # prefered softcoded with
    # key:t value:"${AGENT_TEMPERATURE}"
  AGENT_OPTS="$(jq -n \
    --argjson t "${AGENT_TEMPERATURE}" \
    --argjson p "${AGENT_TOP_P}" \
    --argjson k "${AGENT_TOP_K}" \
    --argjson n "${AGENT_NUM_PREDICT}" \
    --argjson ms "${AGENT_MIROSTAT}" \
    --argjson sd "${AGENT_SEED}" \
    '{temperature:$t,top_p:$p,top_k:$k,num_predict:$n,mirostat:$ms,seed:$sd}')"
}
