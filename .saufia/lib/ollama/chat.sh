ollama::chat() {
  local prompt="$1" sys="${2:-}" opts="${3:-{\}}"
  local url="${OLLAMA_URL:-http://127.0.0.1:11434}"
  local resp
  resp="$(curl -sf "$url/api/chat" -d "$(jq -n \
    --arg m "${AGENT_MODEL:-${MODEL:-llama3}}" --arg s "$sys" --arg p "$prompt" --argjson o "$opts" \
    '{model:$m,messages:[{role:"system",content:$s},{role:"user",content:$p}],stream:false,options:$o}')" \
    2>/dev/null)" || {
    echo "ollama: unreachable ($url) — run: ollama serve &" >&2
    return 1
  }
  printf '%s\n' "$(jq -r '.message.content // empty' <<< "$resp")"
}
