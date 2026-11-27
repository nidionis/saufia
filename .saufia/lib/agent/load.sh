agent::resolve_dir() {
  local name="$1" base="$SAUFIA_CTX/agents" fam
  [[ -d "$base/$name" ]] && { printf '%s' "$base/$name"; return 0; }
  for fam in read write chat tool; do
    [[ -d "$base/$fam/$name" ]] && { printf '%s' "$base/$fam/$name"; return 0; }
  done
  return 1
}
agent::load() {
  local name="${1:-default}" dir
  dir="$(agent::resolve_dir "$name")" || { echo "agent: no '$name'" >&2; return 1; }
  export AGENT_DIR="$dir"
  AGENT_SYSTEM=""
  scope::load "$dir"
  AGENT_SYSTEM="$(prompt::resolve "$dir" 2>/dev/null || true)"
  local opts='{}' key var lc
  for key in TEMPERATURE TOP_P TOP_K NUM_PREDICT MIROSTAT SEED; do
    var="AGENT_${key}"; lc="${key,,}"
    [[ -n "${!var:-}" ]] || continue
    opts="$(jq -n --argjson base "$opts" --argjson v "${!var}" --arg k "$lc" \
      '$base + {($k): $v}')"
  done
  AGENT_OPTS="$opts"
}
