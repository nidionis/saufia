# ollama::list — installed models (name only, one per line)
ollama::list() {
  curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" \
    | jq -r '.models[].name' 2>/dev/null
}

# ollama::available <model> — exact match check
ollama::available() {
  ollama::list | grep -qxF "$1"
}

# ollama::fit <desired> — return best available model.
# Priority: exact match > same family smaller > any smaller > WORST_PREFERED fallback.
# WORST_PREFERED=1 (default): fall back to any available model.
# WORST_PREFERED=0: fail hard if exact not found.
ollama::fit() {
  local want="${1:-${AGENT_MODEL:-$MODEL}}"
  local worst="${WORST_PREFERED:-1}"

  # Exact match
  if ollama::available "$want"; then
    printf '%s\n' "$want"
    return 0
  fi

  # Extract family and size (e.g. "qwen3-coder:1.5b" -> family="qwen3-coder", size=1.5)
  local family="${want%%:*}"
  local tag="${want##*:}"
  local size
  size="$(grep -oP '[0-9]+\.?[0-9]*' <<< "$tag" | head -1)"
  size="${size:-0}"

  # Same family, any size available (prefer closest <= desired)
  local best="" best_size=0
  while IFS= read -r m; do
    local mf="${m%%:*}"
    [[ "$mf" == "$family" ]] || continue
    local ms
    ms="$(grep -oP '[0-9]+\.?[0-9]*' <<< "${m##*:}" | head -1)"
    ms="${ms:-0}"
    # prefer <= desired, closest to it
    if (( $(echo "$ms <= $size" | bc -l 2>/dev/null || echo 0) )); then
      if (( $(echo "$ms > $best_size" | bc -l 2>/dev/null || echo 0) )); then
        best="$m"; best_size="$ms"
      fi
    fi
  done < <(ollama::list)

  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
    return 0
  fi

  # WORST_PREFERED: any model at all (smallest first)
  if [[ "$worst" == "1" ]]; then
    local any
    any="$(ollama::list | head -1)"
    if [[ -n "$any" ]]; then
      printf '%s\n' "$any"
      return 0
    fi
  fi

  # Nothing available
  echo "ollama::fit: no model available for '$want' (WORST_PREFERED=$worst)" >&2
  echo "ollama::fit: run → ollama pull $want" >&2
  return 1
}

# ollama::fit_apply — fit + override AGENT_MODEL in-place
ollama::fit_apply() {
  local fitted
  fitted="$(ollama::fit "${1:-${AGENT_MODEL:-$MODEL}}")" || return 1
  AGENT_MODEL="$fitted"
  echo "ollama::fit_apply: $fitted" >&2
}
