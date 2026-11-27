doc::tree() {
  local ROOT="$1" DEPTH="${2:-$DOC_TREE_DEPTH}" LINE
  while IFS= read -r LINE; do printf '%s\n' "$LINE"
  done < <(find "$ROOT" -maxdepth "$DEPTH" -not -path '*/.git*' -printf '%P\n' 2>/dev/null | sort)
}
doc::vars() {
  local DIR="$1" LINE NAME
  [[ -f "$DIR/config" ]] || return 0
  while IFS= read -r LINE; do
    NAME="${LINE%%=*}"; [[ "$NAME" =~ ^[A-Z][A-Z0-9_]*$ ]] && printf '  - %s\n' "$NAME"
  done < <(grep -E '^[A-Z][A-Z0-9_]*=' "$DIR/config" 2>/dev/null)
}
doc::folder() {
  local DIR="$1" DIGEST
  printf '### %s\n' "${DIR#"$CONTEXT"/}"
  if [[ -f "$DIR/$CONSOLIDATION_DIR" ]]; then
    DIGEST="$(cat "$DIR/$CONSOLIDATION_DIR")"; printf '> %s\n\n' "$DIGEST"
  fi
  doc::vars "$DIR"; printf '\n'
}
doc::render() {
  local OUT="$1" ROOT="$2"; shift 2
  local DIR
  { printf '# %s\n\n## Tree\n\n```\n' "$(basename "$ROOT")"
    doc::tree "$ROOT"; printf '```\n\n'
    for DIR in "${@:-$ROOT}"; do [[ -d "$DIR" ]] && doc::folder "$DIR"; done
  } > "$OUT"
  echo "doc::render: $OUT"
}
doc::readme() {
  local R="$CONTEXT"
  doc::render "$DOT_ROOT/$DOC_OUT_DIR/readme.md"    "$R" "$R"
  doc::render "$DOT_ROOT/$DOC_OUT_DIR/eliza/readme" "$R/agents/chat/eliza" "$R/agents/chat/eliza"
  doc::render "$DOT_ROOT/$DOC_OUT_DIR/git/readme"   "$R/agents/tool/git"   "$R/agents/tool/git"
}
