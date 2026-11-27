# read::targets [args] — files from args, else *.md at the project root
read::targets() {
  local ARG
  if [[ $# -gt 0 ]]; then
    for ARG in "$@"; do
      [[ -f "$ARG" ]] && printf '%s\n' "$ARG"
    done
  else
    find "$MD_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | sort
  fi
}

# read::render <file> — try markdown script, then glow, then cat.
read::render() {
  local FILE="$1"
  local SCRIPT="$CONTEXT/agents/read/text/markdown/scripts/run.sh"
  if [[ -x "$SCRIPT" ]]; then
    "$SCRIPT" < "$FILE"
    return $?
  fi
  # Fallback: glow
  local BIN="${GLOW_PAGER:-glow}"
  if command -v "$BIN" >/dev/null 2>&1; then
    "$BIN" -p --style "${GLOW_STYLE:-notty}" --width "${GLOW_WIDTH:-92}" "$FILE"
    return $?
  fi
  # Last resort: raw cat
  cat "$FILE"
}

# read::run [file...]
read::run() {
  local -a TARGETS=()
  mapfile -t TARGETS < <(read::targets "$@")
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "read::run: no markdown found (tried $MD_DIR/*.md)" >&2
    return 1
  fi
  local F
  for F in "${TARGETS[@]}"; do
    printf '\n'
    read::render "$F"
  done
}

# read::pipe — render stdin
read::pipe() {
  local SCRIPT="$CONTEXT/agents/read/text/markdown/scripts/run.sh"
  if [[ -x "$SCRIPT" ]]; then
    "$SCRIPT"
  elif command -v "${GLOW_PAGER:-glow}" >/dev/null 2>&1; then
    local TMP
    TMP="$(mktemp "${TMPDIR:-/tmp}/saufia-read.XXXXXX.md")"
    cat > "$TMP"
    "${GLOW_PAGER:-glow}" -p --style "${GLOW_STYLE:-notty}" --width "${GLOW_WIDTH:-92}" "$TMP"
    rm -f "$TMP"
  else
    cat
  fi
}
