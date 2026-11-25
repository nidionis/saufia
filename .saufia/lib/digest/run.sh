digest::run() {
  local target; target="$(cd "${1:-.}" && pwd)"
  echo "digest: $target (leaves→root)"
  find "$target" -depth -type d \
    ! -name "$DIGEST_DIR" ! -name .git ! -name node_modules \
    -print0 | while IFS= read -r -d '' d; do
      digest::dir "$d"
    done
  echo "done."
}
