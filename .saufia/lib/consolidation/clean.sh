# consolidation::clean [dir] — remove all .consolidation files
consolidation::clean() {
  local dir; dir="$(cd "${1:-.}" && pwd)"
  find "$dir" -name "$CONSOLIDATION_DIR" -type f -delete 2>/dev/null
  echo "consolidation::clean: $dir"
}
