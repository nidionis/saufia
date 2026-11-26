# search::run [root] <query> — score consolidation files by keyword overlap
search::run() {
  local root="${1:-.}"; shift
  local q="$*"
  find "$root" -name "$CONSOLIDATION_DIR" -type f 2>/dev/null | while read -r f; do
    local score=0 tok
    while read -r tok; do
      grep -qi "$tok" "$f" && (( score++ )) || true
    done < <(echo "$q" | tokenize::run)
    (( score > 0 )) && echo "$score $f"
  done | sort -rn
}
