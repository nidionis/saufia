# mindshark::init <name> — start a fresh trail. 0 loops.
mindshark::init() {
  local NAME="${1:-default}"
  mkdir -p "$MINDSHARK_STATE"
  : > "$MINDSHARK_STATE/$NAME"
  echo "mindshark: started '$NAME'"
}

# mindshark::step <name> <action> — append one step to the trail. 0 loops.
mindshark::step() {
  local NAME="$1" ACTION="$2"
  [[ -f "$MINDSHARK_STATE/$NAME" ]] || mindshark::init "$NAME"
  printf '%s\t%s\n' "$(date +%H:%M:%S)" "$ACTION" >> "$MINDSHARK_STATE/$NAME"
  echo "mindshark: [$NAME] $ACTION"
}

# mindshark::next <name> — the last recorded step (what to do next). 0 loops.
mindshark::next() {
  local NAME="$1" LINE
  [[ -f "$MINDSHARK_STATE/$NAME" ]] || { echo "mindshark: no '$NAME'"; return 1; }
  LINE="$(tail -1 "$MINDSHARK_STATE/$NAME")"
  printf 'next after: %s\n' "${LINE#*$'\t'}"
}

# mindshark::show <name> — print the whole trail. 1 loop.
mindshark::show() {
  local NAME="$1" LINE
  [[ -f "$MINDSHARK_STATE/$NAME" ]] || { echo "mindshark: no '$NAME'"; return 1; }
  while IFS= read -r LINE; do                          # single loop
    printf '  %s\n' "$LINE"
  done < "$MINDSHARK_STATE/$NAME"
}

# mindshark::digest <name> <dir> — fold the trail into <dir>/.digest. 0 loops.
mindshark::digest() {
  local NAME="$1" DIR="${2:-.}"
  [[ -f "$MINDSHARK_STATE/$NAME" ]] || { echo "mindshark: no '$NAME'"; return 1; }
  mkdir -p "$DIR"
  printf 'workflow %s: %s steps, last: %s\n' "$NAME" \
    "$(wc -l < "$MINDSHARK_STATE/$NAME")" \
    "$(tail -1 "$MINDSHARK_STATE/$NAME" | cut -f2-)" > "$DIR/$CONSOLIDATION_DIR"
  echo "mindshark: digest -> $DIR/$CONSOLIDATION_DIR"
}

# mindshark::dispatch <sub> [args] — registry. 0 loops.
mindshark::dispatch() {
  local SUB="${1:-show}"; shift || true
  declare -A REG=( [init]=mindshark::init [step]=mindshark::step
                   [next]=mindshark::next [show]=mindshark::show
                   [digest]=mindshark::digest )
  local FN="${REG[$SUB]:-}"
  [[ -n "$FN" ]] || { echo "mindshark: unknown sub '$SUB'" >&2; return 1; }
  "$FN" "$@"
}
