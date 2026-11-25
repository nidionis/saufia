# scope::load [dir] — source every config from CTX root down to dir.
# Deepest scope wins. THE config mechanism; nothing else loads vars.
scope::load() {
  local target="${1:-$PWD}"
  local -a chain=()
  local d="$target"
  while :; do
    [[ -f "$d/config" ]] && chain+=("$d/config")
    [[ "$d" == "$SAUFIA_CTX" || "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  local i
  for (( i=${#chain[@]}-1; i>=0; i-- )); do
    source "${chain[i]}"
  done
}
