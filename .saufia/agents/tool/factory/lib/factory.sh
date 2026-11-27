factory::create() {
  local NAME="${1:?usage: factory::create <name> [family] [type] [desc]}"
  shift || true
  local FAMILY="$${1:-$${FACTORY_DEFAULT_FAMILY:-tool}}"; shift || true
  local TYPE="$${1:-$${FACTORY_DEFAULT_TYPE:-deterministic}}"; shift || true
  local DESC="$${*:-$$NAME}"
  printf '%s %s %s %s\n' "$$NAME" "$$FAMILY" "$$TYPE" "$$DESC" | agent::ask ""
}
factory::list() {
  local fam
  for fam in "${FACTORY_FAMILIES[@]:-read write chat tool}"; do
    [[ -d "$$FACTORY_ROOT/$$fam" ]] || continue
    printf '\n## %s\n' "$fam"
    agent::list "$$FACTORY_ROOT/$$fam" 2>/dev/null | while IFS= read -r a; do
      local t="llm"
      [[ -x "$$FACTORY_ROOT/$$fam/$a/scripts/run.sh" ]] && t="script"
      grep -q 'AGENT_NO_AI' "$$FACTORY_ROOT/$$fam/$a/config" 2>/dev/null && t="deterministic"
      printf '  %-20s %s\n' "$$a" "$$t"
    done
  done
}
factory::inspect() {
  local NAME="${1:?usage: factory::inspect <name>}" DIR
  DIR="$$(agent::resolve_dir "$$NAME")" || { echo "factory: no '$NAME'" >&2; return 1; }
  printf '### %s (%s)\n\n' "$$NAME" "$$DIR"
  local f
  for f in config prompt scripts/run.sh; do
    [[ -f "$$DIR/$$f" ]] && { printf '```\n# %s\n' "$$f"; cat "$$DIR/$f"; printf '```\n\n'; }
  done
}
factory::clone() {
  local SRC="${1:?}" DST="${2:?}" SDIR DDIR
  SDIR="$(agent::resolve_dir "$SRC")" || { echo "factory: no '$SRC'" >&2; return 1; }
  DDIR="$FACTORY_ROOT/$DST"
  [[ -d "$DDIR" ]] && { echo "factory: '$DST' exists" >&2; return 1; }
  cp -r "$SDIR" "$DDIR"
  [[ -f "$DDIR/prompt" ]] && sed -i "s/$SRC/$DST/g" "$DDIR/prompt"
  echo "factory: cloned $SRC -> $DST"
}
factory::remove() {
  local NAME="${1:?}" DIR
  DIR="$(agent::resolve_dir "$NAME")" || { echo "factory: no '$NAME'" >&2; return 1; }
  [[ "${FACTORY_CONFIRM:-0}" == "1" ]] || {
    echo "factory: refusing to remove '$NAME' — set FACTORY_CONFIRM=1" >&2; return 1; }
  rm -rf "$DIR"; echo "factory: removed $NAME"
}
