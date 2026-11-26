# verb::list — every name::verb defined in lib/
verb::list() {
  grep -rhoE '^[a-z][a-z0-9_]*::[a-z][a-z0-9_]*\(\)' "$CONTEXT/lib" 2>/dev/null \
    | sed 's/()//' | sort -u || true
}

# verb::exists <name::verb>
verb::exists() { declare -F "\$1" >/dev/null 2>&1; }

# verb::run <name::verb> [args] — dispatch a loaded verb.
# The active agent is whatever init loaded (@agent prefix or default).
verb::run() {
  local VERB="\$1"; shift || true
  if ! verb::exists "$VERB"; then
    echo "verb::run: '$VERB' not defined (try: \$0 @agent help::verbs)" >&2
    return 1
  fi
  printf '[$SAUFIA_AGENT] %s %s\n' "$VERB" "$*" >&2
  "$VERB" "$@"
}
