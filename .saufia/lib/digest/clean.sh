digest::clean() {
  local dir; dir="$(cd "${1:-.}" && pwd)"
  find "$dir" -name "$DIGEST_DIR" -type f -delete 2>/dev/null
  echo "cleaned: $dir"
}
