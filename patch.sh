#!/usr/bin/env bash
# patch.sh — v2: resolve_dir fix + ollama fit/pull helpers
# Usage: cd ~/.svr/saufia && bash patch.sh
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$_here/.saufia" ]] || { echo "patch: run from project root" >&2; exit 1; }

PATCHED=0
fix() { printf '  fixed: %s\n' "$1"; (( ++PATCHED )); }

# ─── 1. agent::resolve_dir — find agent in read/ write/ chat/ subdirs ─────────
echo "[1/5] lib/agent/load.sh — resolve_dir"
cat > "$_here/.saufia/lib/agent/load.sh" <<'EOF'
# agent::resolve_dir <name> — search agents/, then agents/{read,write,chat}/
agent::resolve_dir() {
  local name="$1" base="$SAUFIA_CTX/agents" fam
  [[ -d "$base/$name" ]] && { printf '%s' "$base/$name"; return 0; }
  for fam in read write chat; do
    [[ -d "$base/$fam/$name" ]] && { printf '%s' "$base/$fam/$name"; return 0; }
  done
  return 1
}

agent::load() {
  local name="${1:-default}" dir
  dir="$(agent::resolve_dir "$name")" || { echo "agent: no '$name'" >&2; return 1; }
  scope::load "$dir"
  AGENT_SYSTEM="$(prompt::resolve "$dir" || true)"
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
fix "lib/agent/load.sh (resolve_dir for family subdirs)"

# ─── 2. agent::show — use resolve_dir ─────────────────────────────────────────
echo "[2/5] lib/agent/list.sh — show uses resolve_dir"
cat > "$_here/.saufia/lib/agent/list.sh" <<'EOF'
# agent::list [root] — folders holding a config file.
agent::list() {
  local ROOT="${1:-$CONTEXT/agents}" DIR
  [[ -d "$ROOT" ]] || return 1
  while IFS= read -r -d '' DIR; do
    [[ -f "$DIR/config" ]] || continue
    printf '%s\n' "${DIR#"$ROOT"/}"
  done < <(find "$ROOT" -mindepth 1 -type d -print0 2>/dev/null | sort -z)
}

# agent::show <name> — dump config + prompt (pure bash, family-aware)
agent::show() {
  local NAME="$1" DIR
  DIR="$(agent::resolve_dir "$NAME")" || { echo "agent::show: no '$NAME'" >&2; return 1; }
  printf '### %s\n' "$NAME"
  [[ -f "$DIR/config" ]] && { printf '```\n'; cat "$DIR/config"; printf '```\n'; }
  [[ -f "$DIR/prompt" ]] && { printf '```\n'; cat "$DIR/prompt"; printf '```\n'; }
}

# agent::tree — indented from path depth
agent::tree() {
  local ROOT="${1:-$CONTEXT/agents}" NAME DEPTH
  agent::list "$ROOT" | while IFS= read -r NAME; do
    DEPTH="$(tr -dc '/' <<< "$NAME" | wc -c)"
    printf '%*s%s\n' $((DEPTH * 2)) '' "${NAME##*/}"
  done
}

agent_list() { agent::list "$@"; }
EOF
fix "lib/agent/list.sh (show uses resolve_dir)"

# ─── 3. lib/ollama/pull.sh — emit the pull command for current model ──────────
echo "[3/5] lib/ollama/pull.sh"
mkdir -p "$_here/.saufia/lib/ollama"
cat > "$_here/.saufia/lib/ollama/pull.sh" <<'EOF'
# ollama::pull [model] — print the pull command for a model (copy-paste ready)
# Falls back to current AGENT_MODEL or root MODEL.
ollama::pull() {
  local m="${1:-${AGENT_MODEL:-$MODEL}}"
  echo "ollama pull $m"
}

# ollama::serve — print the serve command if ollama isn't running
ollama::serve() {
  if curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" >/dev/null 2>&1; then
    echo "# ollama already running at ${OLLAMA_URL:-http://127.0.0.1:11434}"
  else
    echo "ollama serve &"
    echo "# then: ollama pull ${AGENT_MODEL:-$MODEL}"
  fi
}

# ollama::check — one-liner status
ollama::check() {
  if ! curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" >/dev/null 2>&1; then
    echo "OFFLINE — run: ollama serve &" >&2
    return 1
  fi
  echo "ONLINE — ${OLLAMA_URL:-http://127.0.0.1:11434}"
}
EOF
fix "lib/ollama/pull.sh (pull/serve/check)"

# ─── 4. lib/ollama/fit.sh — find best available model ─────────────────────────
echo "[4/5] lib/ollama/fit.sh"
cat > "$_here/.saufia/lib/ollama/fit.sh" <<'EOF'
# ollama::list — installed models (name only, one per line)
ollama::list() {
  curl -sf "${OLLAMA_URL:-http://127.0.0.1:11434}/api/tags" \
    | jq -r '.models[].name' 2>/dev/null
}

# ollama::available <model> — exact match check
ollama::available() {
  ollama::list | grep -qxF "$1"
}

# ollama::fit <desired> — return best available model.
# Priority: exact match > same family smaller > any smaller > WORST_PREFERED fallback.
# WORST_PREFERED=1 (default): fall back to any available model.
# WORST_PREFERED=0: fail hard if exact not found.
ollama::fit() {
  local want="${1:-${AGENT_MODEL:-$MODEL}}"
  local worst="${WORST_PREFERED:-1}"

  # Exact match
  if ollama::available "$want"; then
    printf '%s\n' "$want"
    return 0
  fi

  # Extract family and size (e.g. "qwen3-coder:1.5b" -> family="qwen3-coder", size=1.5)
  local family="${want%%:*}"
  local tag="${want##*:}"
  local size
  size="$(grep -oP '[0-9]+\.?[0-9]*' <<< "$tag" | head -1)"
  size="${size:-0}"

  # Same family, any size available (prefer closest <= desired)
  local best="" best_size=0
  while IFS= read -r m; do
    local mf="${m%%:*}"
    [[ "$mf" == "$family" ]] || continue
    local ms
    ms="$(grep -oP '[0-9]+\.?[0-9]*' <<< "${m##*:}" | head -1)"
    ms="${ms:-0}"
    # prefer <= desired, closest to it
    if (( $(echo "$ms <= $size" | bc -l 2>/dev/null || echo 0) )); then
      if (( $(echo "$ms > $best_size" | bc -l 2>/dev/null || echo 0) )); then
        best="$m"; best_size="$ms"
      fi
    fi
  done < <(ollama::list)

  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
    return 0
  fi

  # WORST_PREFERED: any model at all (smallest first)
  if [[ "$worst" == "1" ]]; then
    local any
    any="$(ollama::list | head -1)"
    if [[ -n "$any" ]]; then
      printf '%s\n' "$any"
      return 0
    fi
  fi

  # Nothing available
  echo "ollama::fit: no model available for '$want' (WORST_PREFERED=$worst)" >&2
  echo "ollama::fit: run → ollama pull $want" >&2
  return 1
}

# ollama::fit_apply — fit + override AGENT_MODEL in-place
ollama::fit_apply() {
  local fitted
  fitted="$(ollama::fit "${1:-${AGENT_MODEL:-$MODEL}}")" || return 1
  AGENT_MODEL="$fitted"
  echo "ollama::fit_apply: $fitted" >&2
}
EOF
fix "lib/ollama/fit.sh (list/available/fit/fit_apply)"

# ─── 5. Wire fit into init: auto-fit on load if model missing ─────────────────
echo "[5/5] lib/init.sh — auto-fit after agent::load"
# Append the fit hook at end of init.sh (idempotent: check before append)
if ! grep -q 'ollama::fit_apply' "$_here/.saufia/lib/init.sh" 2>/dev/null; then
  cat >> "$_here/.saufia/lib/init.sh" <<'EOF'

# Auto-fit: if the loaded model isn't installed, pick the best available.
# Set WORST_PREFERED=0 in config to disable fallback.
if [[ "${OLLAMA_FIT:-1}" == "1" ]] && declare -F ollama::fit_apply >/dev/null 2>&1; then
  if ! ollama::available "${AGENT_MODEL:-$MODEL}" 2>/dev/null; then
    ollama::fit_apply "${AGENT_MODEL:-$MODEL}" || true
  fi
fi
EOF
  fix "lib/init.sh (auto-fit hook)"
else
  echo "  skip: init.sh already has fit hook"
fi

# ─── 6. Add config vars ───────────────────────────────────────────────────────
if ! grep -q 'WORST_PREFERED' "$_here/.saufia/config" 2>/dev/null; then
  cat >> "$_here/.saufia/config" <<'EOF'

# === Ollama fit ===
WORST_PREFERED=1          # 1=allow smaller fallback, 0=strict exact match
OLLAMA_FIT=1              # 1=auto-fit on load, 0=skip
EOF
  fix "config (WORST_PREFERED, OLLAMA_FIT)"
fi

# ─── 7. chmod ─────────────────────────────────────────────────────────────────
chmod +x "$_here"/bin/saufia* 2>/dev/null || true

# ─── Summary ──────────────────────────────────────────────────────────────────
echo
echo "Done. $PATCHED fixes applied."
echo
echo "Test:"
echo "  ./bin/saufia @write/coder ask 'hello'"
echo "  ./bin/saufia @default ollama::fit"
echo "  ./bin/saufia @default ollama::list"
echo "  ./bin/saufia @default ollama::pull"
