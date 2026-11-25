digest::dir() {
  local dir="\$1" out="\$1/$DIGEST_DIR"
  local content summary
  content="$(find "$dir" -maxdepth 1 -type f ! -name "$DIGEST_DIR" 2>/dev/null \
    -exec strings {} + | head -n "${TOKENS_DIV:-200}")"
  [[ -n "$content" ]] || { echo "(empty)" > "$out"; return; }
  summary="$(agent::ask "Summarize in 2 sentences max:
$content")"
  printf '%s\n' "${summary:-empty}" > "$out"
  echo "  $out"
}
