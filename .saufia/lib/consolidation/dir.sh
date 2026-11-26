# consolidation::dir <dir> — summarize one directory
consolidation::dir() {
  local dir="$1"
  local out="$dir/$CONSOLIDATION_DIR"
  local content summary

  content="$(find "$dir" -maxdepth 1 -type f \
    ! -name "$CONSOLIDATION_DIR" ! -name ".consolidation" 2>/dev/null \
    -exec strings {} + | head -n "${CONSOLIDATION_MAX_LINES:-200}")"

  if [[ -z "$content" ]]; then
    printf '(empty)\n' > "$out"
    return
  fi

  summary="$(agent::ask "Summarize in 2 sentences max:
$content")"
  printf '%s\n' "${summary:-empty}" > "$out"
  echo "  $out"
}
