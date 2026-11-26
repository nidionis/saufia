# guard::exec <code> — extract fence, validate, sandbox-execute
guard::exec() {
  local code="$1" lang body rc=0
  guard::load || return $?

  lang="$(grep -oP '^```\K\w+' <<< "$code" | head -1)"
  lang="${lang:-bash}"

  # awk toggle: more robust than sed range for nested/leading content
  if grep -q '^```' <<< "$code"; then
    body="$(awk '/^```/{f=!f; next} f' <<< "$code")"
  else
    body="$code"
  fi

  guard::check "$body" || return 1
  command -v "$lang" >/dev/null 2>&1 || {
    echo "guard::exec: no '$lang'" >&2; return 127; }

  local tmp; tmp="$$(mktemp "$$SANDBOX_DIR/run.XXXXXX")"
  printf '%s\n' "$$body" > "$$tmp"
  timeout "$$TIMEOUT" "$$lang" "$$tmp" || rc=$$?
  rm -f "$tmp"
  (( rc == 124 || rc == 137 )) && echo "guard::exec: TIMEOUT ${TIMEOUT}s" >&2
  return "$rc"
}
