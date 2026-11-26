#!/usr/bin/env bash
set -euo pipefail

# === patch.sh — saufia fix ===
# Usage: cd ~/.svr/saufia && bash patch.sh
# Idempotent: safe to re-run.

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$_here/.saufia" ]] || { echo "patch: run from project root (need .saufia/)" >&2; exit 1; }

PATCHED=0
fix() { printf '  fixed: %s\n' "$1"; (( ++PATCHED )); }

# ─── 1. chmod all bin/ scripts ─────────────────────────────────────────────────
echo "[1/7] chmod bin/"
for f in "$_here"/bin/saufia*; do
  [[ -f "$f" ]] && chmod +x "$f"
done
fix "bin/ executable bits"

# ─── 2. Fix bin/saufia — remove infinite-loop trap (exec "$0") ────────────────
echo "[2/7] bin/saufia"
cat > "$_here/bin/saufia" <<'EOF'
#!/usr/bin/env bash
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONTEXT="${CONTEXT:-${SAUFIA_CTX:-$_here/../.saufia}}"
export SAUFIA_CTX="$CONTEXT"
export PROG="$(basename "$0")"
[[ "${1:-}" == @* ]] && { export SAUFIA_AGENT="${1#@}"; shift; }

CMD="${1:-help}"; shift || true
SUB="$_here/saufia-$CMD"
[[ -x "$SUB" ]] && exec "$SUB" "$@"

source "$CONTEXT/lib/init.sh"
if verb::exists "$CMD"; then
  verb::run "$CMD" "$@"
  exit $?
fi
echo "saufia: no command or verb '$CMD' (try: saufia help)" >&2
exit 1
EOF
chmod +x "$_here/bin/saufia"
fix "bin/saufia (removed exec \$0 infinite-loop)"

# ─── 3. Fix agents/why/prompt — $BASH_SOURCE expanded at source-time ──────────
echo "[3/7] agents/why/prompt"
cat > "$_here/.saufia/agents/why/prompt" <<'EOF'
Explain {I}. {I} origin.
EOF
fix "agents/why/prompt ({I} placeholder)"

# ─── 4. Fix lib/prompt/stack.sh — \$1 was literal, not expanded ───────────────
echo "[4/7] lib/prompt/stack.sh"
cat > "$_here/.saufia/lib/prompt/stack.sh" <<'EOF'
# prompt::stack <dir> [question] — append all prompts in dir as context
prompt::stack() {
  local dir="$1" q="${2:-}"
  local ctx=""
  if [[ -f "$dir/prompt" ]]; then
    ctx="$(cat "$dir/prompt")"
  fi
  local f
  for f in "$dir"/*.prompt; do
    [[ -f "$f" ]] && ctx+=$'\n'"$(cat "$f")"
  done
  agent::ask "$ctx
$q"
}
EOF
fix "lib/prompt/stack.sh"

# ─── 5. Fix lib/doc/make.sh — \$1/\$2 were literal ────────────────────────────
echo "[5/7] lib/doc/make.sh"
cat > "$_here/.saufia/lib/doc/make.sh" <<'EOF'
# doc::make <topic> [format] — pipeline: classer>summarize>owto>note>formator
doc::ask_step() {
  local agent="$1" input="$2"
  agent::load "$agent"
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    prompt::ask "$input"
  else
    printf '%s\n' "$input"
  fi
}

doc::make() {
  local topic="$1" fmt="${2:-md}"
  local scratch
  scratch="$(mktemp -d "${CONTEXT:-.}/.state/doc.XXXXXX")"

  doc::ask_step "classer"   "$topic"                    > "$scratch/class"
  doc::ask_step "summarize" "$(cat "$scratch/class")"   > "$scratch/sum"
  doc::ask_step "owto"      "$topic"                    > "$scratch/how"
  doc::ask_step "note"      "$(cat "$scratch/sum")"     > "$scratch/note"

  local heap
  heap="$(cat "$scratch/class" "$scratch/sum" "$scratch/how" "$scratch/note")"

  agent::load "formator"
  FILETYPE="$fmt" prompt::ask "$heap"
  rm -rf "$scratch"
}
EOF
fix "lib/doc/make.sh"

# ─── 6. Fix lib/doc/man.sh + markdown.sh — same \$1 escaping bug ─────────────
echo "[6/7] lib/doc/man.sh + markdown.sh"
cat > "$_here/.saufia/lib/doc/man.sh" <<'EOF'
# doc::man <topic>
doc::man() {
  agent::load "man"
  prompt::ask "$1"
}
EOF

cat > "$_here/.saufia/lib/doc/markdown.sh" <<'EOF'
# doc::markdown <topic>
doc::markdown() {
  agent::load "markdown"
  prompt::ask "$1"
}
EOF
fix "lib/doc/man.sh + markdown.sh"

# ─── 7. Fix lib/verb/run.sh — \$1 was literal ─────────────────────────────────
echo "[7/7] lib/verb/run.sh"
cat > "$_here/.saufia/lib/verb/run.sh" <<'EOF'
# verb::list — every name::verb defined in lib/
verb::list() {
  grep -rhoE '^[a-z][a-z0-9_]*::[a-z][a-z0-9_]*\(\)' "$CONTEXT/lib" 2>/dev/null \
    | sed 's/()//' | sort -u || true
}

# verb::exists <name::verb>
verb::exists() { declare -F "$1" >/dev/null 2>&1; }

# verb::run <name::verb> [args] — dispatch a loaded verb.
verb::run() {
  local VERB="$1"; shift || true
  if ! verb::exists "$VERB"; then
    echo "verb::run: '$VERB' not defined (try: $0 @agent help::verbs)" >&2
    return 1
  fi
  printf '[%s] %s %s\n' "${SAUFIA_AGENT:-default}" "$VERB" "$*" >&2
  "$VERB" "$@"
}
EOF
fix "lib/verb/run.sh"

# ─── 8. Ensure .state/ exists (used by junior, thinker, doc) ──────────────────
mkdir -p "$_here/.saufia/.state"
fix ".saufia/.state/"

# ─── Summary ───────────────────────────────────────────────────────────────────
echo
echo "Done. $PATCHED fixes applied."
echo "Test: saufia @cold ask 'what is a race condition'"
