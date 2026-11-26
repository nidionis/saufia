# saufia bootstrap — self-locating, deterministic sourcing
saufia::find_ctx() {
  local d="${1:-$PWD}"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/.saufia" ]] && { echo "$d/.saufia"; return 0; }
    d="$(dirname "$d")"
  done
  echo "$PWD/.saufia"
}

CONTEXT="${CONTEXT:-$(saufia::find_ctx)}"
export CONTEXT

# Source libs in deterministic order (alphabetical via glob is fine here
# because no lib depends on another lib's function at source-time)
for _f in "$CONTEXT"/lib/*/*.sh; do
  [[ -f "$_f" ]] && source "$_f"
done

# Load root config (global vars: MODEL, OLLAMA_URL, aliases...)
source "$CONTEXT/config"

# Load agent (calls scope::load internally, walks root->agent)
agent::load "${SAUFIA_AGENT:-default}"
