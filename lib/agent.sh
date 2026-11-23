load_agent() {
  local name="${1:-$DEFAULT_AGENT}"
  local dir="$SAUFIA_ROOT/agents/$name"
  [[ -d "$dir" ]] || { echo "no agent: $name" >&2; return 1; }
  [[ -f "$dir/conf" ]] && source "$dir/conf"
  AGENT_SYSTEM=""
  [[ -f "$dir/prompt" ]] && AGENT_SYSTEM="$(cat "$dir/prompt")"
  AGENT_OPTS="$(jq -n \
    --argjson t "${AGENT_TEMPERATURE:-0.7}" \
    --argjson p "${AGENT_TOP_P:-0.9}" \
    --argjson k "${AGENT_TOP_K:-40}" \
    --argjson n "${AGENT_NUM_PREDICT:-256}" \
    --argjson r "${AGENT_REPEAT_LAST_N:-64}" \
    --argjson rp "${AGENT_REPEAT_PENALTY:-1.1}" \
    --argjson sd "${AGENT_SEED:-0}" \
    --argjson nk "${AGENT_NUM_KEEP:-0}" \
    '{temperature:$t,top_p:$p,top_k:$k,num_predict:$n,repeat_last_n:$r,
      repeat_penalty:$rp,seed:$sd,num_keep:$nk}')"
}
ask() { ollama_chat "$1" "${2:-$AGENT_SYSTEM}" "$AGENT_OPTS"; }
