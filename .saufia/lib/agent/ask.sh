agent::ask() {
  ollama::chat "$1" "${2:-$AGENT_SYSTEM}" "$AGENT_OPTS"
}
