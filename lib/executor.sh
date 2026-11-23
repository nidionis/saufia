executor() {
  local code="$1" lang="${2:-}"
  [[ -z "$lang" ]] && lang=$(grep -oP '^```\K\w+' <<< "$code" | head -1 || true)
  lang="${lang:-sh}"
  local body
  grep -q '^```' <<< "$code" && body=$(sed '/^```/,/^```/{/^```/d}' <<< "$code") || body="$code"
  guard "$body" "llm" || return 1
  local interp
  interp=$(awk -F'\t' -v l="$lang" '\$1==l{print \$2}' "$SAUFIA_ROOT/conf/interpreters")
  interp="${interp:-$lang}"
  command -v "$interp" &>/dev/null || { echo "EXEC: no '$interp'" >&2; return 127; }
  local tmp; tmp=$(mktemp "$SAUFIA_LOG_DIR/X.XXXXXX")
  printf '%s\n' "$body" > "$tmp"
  echo "EXEC: $interp" >&2
  "$interp" "$tmp"; local rc=$?
  rm -f "$tmp"; return $rc
}
