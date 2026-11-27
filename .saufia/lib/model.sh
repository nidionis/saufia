# model::* — right-size the optional AI layer.
# DUMMY  = no logic, quick summary; BASIC = digesting; MEDIUM = code.

model::tier() {
  local m="${1:-${AGENT_MODEL:-$RIGHT_SIZE_MODEL}}"
  case "$m" in
    "$DUMMY_MODEL"|smollm2:*)     printf 'dummy\n' ;;
    "$BASIC_MODEL"|qwen3:0.6b*)   printf 'basic\n' ;;
    "$MEDIUM_MODEL"|qwen3-coder:*) printf 'medium\n' ;;
    *)                            printf 'custom\n' ;;
  esac
}

model::size() {
  case "$(model::tier "${1:-}")" in
    dummy)  printf '%s\n' "${DUMMY_SIZE:-64}" ;;
    basic)  printf '%s\n' "${BASIC_SIZE:-256}" ;;
    medium) printf '%s\n' "${GATHA_SIZE:-512}" ;;
    *)      printf '%s\n' "${AGENT_NUM_PREDICT:-${BASIC_SIZE:-256}}" ;;
  esac
}

model::set() {
  case "${1:-}" in
    dummy)  AGENT_MODEL="$DUMMY_MODEL" ;;
    basic)  AGENT_MODEL="$BASIC_MODEL" ;;
    medium) AGENT_MODEL="$MEDIUM_MODEL" ;;
    *) echo "model::set: usage: model::set <dummy|basic|medium>" >&2; return 1 ;;
  esac
  export AGENT_MODEL
  printf 'model: %s (%s)\n' "$AGENT_MODEL" "$(model::tier)"
}

model::right_size() { printf '%s\n' "${RIGHT_SIZE_MODEL:-${DUMMY_MODEL:-$MODEL}}"; }
