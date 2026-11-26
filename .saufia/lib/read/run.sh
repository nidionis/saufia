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

# read::run [file...] — glow if available/installable, else coldiest
read::run() {
  local -a TARGETS=()
  mapfile -t TARGETS < <(read::targets "$@")

  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "read::run: no markdown found (tried $MD_DIR/*.md)" >&2
    return 1
  fi

  agent::load "read"
  local BIN="${GLOW_PAGER:-glow}"

  if ! command -v "$BIN" >/dev/null 2>&1; then
    if install::need "$BIN" "${GLOW_PKG:-glow}" 2>/dev/null; then
      :
    else
      echo "read::run: '$BIN' unavailable — falling back to coldiest" >&2
      local F
      for F in "${TARGETS[@]}"; do
        printf '\n\033[1m== %s ==\033[0m\n' "$F"
        prompt::ask "Render this markdown as readable plain text:
$(cat "$F")"
      done
      return 0
    fi
  fi

  "$BIN" -p --style "${GLOW_STYLE:-notty}" --width "${GLOW_WIDTH:-92}" "${TARGETS[@]}"
}

# read::pipe — render stdin (for: saufia-read < README.md)
read::pipe() {
  agent::load "read"
  local BIN="${GLOW_PAGER:-glow}" TMP
  if command -v "$BIN" >/dev/null 2>&1 || install::need "$BIN" "${GLOW_PKG:-glow}" 2>/dev/null; then
    TMP="$(mktemp "${TMPDIR:-/tmp}/saufia-read.XXXXXX.md")"
    cat > "$TMP"
    "$BIN" -p --style "${GLOW_STYLE:-notty}" --width "${GLOW_WIDTH:-92}" "$TMP"
    rm -f "$TMP"
  else
    cat
  fi
}
