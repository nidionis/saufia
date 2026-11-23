ollama_chat() {
  local prompt="$1" sys="${2:-}" opts="${3:-{\}}"
  curl -sf "$OLLAMA_URL/api/chat" -d "$(jq -n \
    --arg m "$AGENT_MODEL" --arg s "$sys" --arg p "$prompt" --argjson o "$opts" \
    '{model:$m,messages:[{role:"system",content:$s},{role:"user",content:$p}],stream:false,options:$o}'
  )" | jq -r '.message.content // empty'
}
