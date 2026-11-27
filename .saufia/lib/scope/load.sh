scope::load() {
  local target="${1:-$PWD}"
  local -a chain=()
  local d="$target"
  while :; do
    [[ -f "$d/config" ]] && chain+=("$d/config")
    [[ "$d" == "$CONTEXT" || "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  local i
  for (( i=${#chain[@]}-1; i>=0; i-- )); do
    source "${chain[i]}" 2>/dev/null || true
  done
}
