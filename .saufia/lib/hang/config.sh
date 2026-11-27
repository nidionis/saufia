hang::config() {
  local KEY="$1" DIR="${2:-${AGENT_DIR:-$CONTEXT}}"
  local d="$DIR" val=""
  while [[ "$d" != "/" ]]; do
    if [[ -f "$d/config" ]]; then
      local found
      found="$(grep -m1 "^${KEY}=" "$d/config" 2>/dev/null | cut -d= -f2- | sed 's/^["'\'']//;s/["'\'']$//')"
      [[ -n "$found" ]] && val="$found"
    fi
    [[ "$d" == "$CONTEXT" ]] && break
    d="$(dirname "$d")"
  done
  if [[ -z "$val" && -f "$CONTEXT/config" ]]; then
    val="$(grep -m1 "^${KEY}=" "$CONTEXT/config" 2>/dev/null | cut -d= -f2- | sed 's/^["'\'']//;s/["'\'']$//')"
  fi
  printf '%s' "$val"
}
hang::require() {
  local KEY="$1" val
  val="$(hang::config "$KEY")"
  [[ -n "$val" ]] || { echo "hang::require: '$KEY' undefined in config tree" >&2; return 1; }
  printf '%s' "$val"
}
hang::hook() {
  local LINE="$1" CMD="$2"
  if [[ "$CMD" =~ ([A-Z_][A-Z0-9_]*) ]]; then
    local KEY="${BASH_REMATCH[1]}" val
    val="$(hang::config "$KEY")"
    if [[ -n "$val" ]]; then eval "$KEY=\$val"
      echo "hang::hook: resolved $KEY=$val (line $LINE)" >&2; return 0; fi
  fi
  return 1
}
