# ollama::pull [model] — print the pull command for a model (copy-paste ready)
# Falls back to current AGENT_MODEL or root MODEL.
ollama::pull() {
  local m="${1:-${AGENT_MODEL:-$MODEL}}"
  echo "ollama pull $m"
}

# ollama::serve — print the serve command if ollama isn't running
ollama::serve() {
  if curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" >/dev/null 2>&1; then
    echo "# ollama already running at ${OLLAMA_URL:-http://127.0.0.1:11434}"
  else
    echo "ollama serve &"
    echo "# then: ollama pull ${AGENT_MODEL:-$MODEL}"
  fi
}

# ollama::check — one-liner status
ollama::check() {
  if ! curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" >/dev/null 2>&1; then
    echo "OFFLINE — run: ollama serve &" >&2
    return 1
  fi
  echo "ONLINE — ${OLLAMA_URL:-http://127.0.0.1:11434}"
}
