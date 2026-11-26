# consolidation::run [dir] — walk tree, write .consolidation per dir
consolidation::run() {
  local target; target="$(cd "${1:-.}" && pwd)"
  echo "consolidation: $target (leaves to root)"
  find "$target" -depth -type d \
    ! -name ".git" ! -name "node_modules" ! -name "$CONSOLIDATION_DIR" \
    -print0 | while IFS= read -r -d '' d; do
      consolidation::dir "$d"
    done
  echo "done."
}
