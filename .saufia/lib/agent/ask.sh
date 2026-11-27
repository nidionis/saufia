#!/usr/bin/bash
agent::ask() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  local run="${AGENT_DIR:-}/scripts/run.sh"
  if [[ -x "$run" ]]; then
    printf '%s\n' "$P" | "$run"; return $?
  fi
  [[ "${S:-}" == NO_AI ]] && return 0
  ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
}
agent::ask_if_llm() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  if [[ "${DOC_USE_LLM:-0}" == "1" ]]; then
    ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
    return 0
  fi
  printf '%s\n' "${S:-$P}"
}
