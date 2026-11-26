#!/usr/bin/env bash
# patch.sh — agent::load : construction JSON par jq (aucun join bash)
set -uo pipefail
cd "${1:-$PWD}"
[[ -f lib/agent/load.sh ]] || { echo "pas a la racine .saufia/"; exit 1; }
mkdir -p .bak
cp -f lib/agent/load.sh .bak/load.sh.bak
cat > lib/agent/load.sh <<'EOF'
agent::load() {
local name="${1:-default}"
local dir="$SAUFIA_CTX/agents/$name"
[[ -d "$dir" ]] || { echo "agent: no '$name'" >&2; return 1; }
scope::load "$dir"
AGENT_SYSTEM="$(prompt::resolve "$dir" || true)"
# build opts incrementally with jq; never hand-join JSON in bash
local opts='{}' key var lc
for key in TEMPERATURE TOP_P TOP_K NUM_PREDICT MIROSTAT SEED; do
var="AGENT_${key}"; lc="${key,,}"
[[ -n "${!var:-}" ]] || continue
opts="$(jq -n --argjson base "$opts" --argjson v "${!var}" --arg k "$lc" \
'$base + {($k): $v}')"
done
AGENT_OPTS="$opts"
}
EOF
echo "patched: lib/agent/load.sh (jq merge, robuste)"
