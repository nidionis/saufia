#!/usr/bin/bash
agent::ask() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  local run="${AGENT_DIR:-}/scripts/run.sh"
  if [[ ! -x "$run" ]]; then
    local alt="${AGENT_DIR:-}/script/bin/${AGENT_DIR##*/}"
    [[ -x "$alt" ]] && run="$alt"
  fi
  if [[ -x "$run" ]]; then
    printf '%s\n' "$P" | "$run"
    return $?
  fi
  [[ "${S:-}" == NO_AI ]] && return 0
  [[ "${AGENT_NO_AI:-0}" == "1" ]] && return 0
  if [[ "${AGENT_SCRIPT_ONLY:-0}" == "1" ]]; then
    echo "agent: '${AGENT_NAME:-?}' is script-only — use its bin/verb" >&2
    return 0
  fi
  ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
}
agent::ask_if_llm() {
  local P="$1" S="${2:-${AGENT_SYSTEM:-}}"
  if [[ "${DOC_USE_LLM:-0}" == "1" && "${AGENT_NO_AI:-0}" != "1" ]]; then
    ollama::chat "$P" "$S" "${AGENT_OPTS:-{\}}" | llm::strip_think
    return 0
  fi
  printf '%s\n' "${S:-$P}"
}
