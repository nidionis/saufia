# saufia bootstrap — self-locating, deterministic sourcing
saufia::find_ctx() {
  local d="${1:-$PWD}"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/.saufia" ]] && { echo "$d/.saufia"; return 0; }
    d="$(dirname "$d")"
  done
  echo "$PWD/.saufia"
}

SAUFIA_CTX="${SAUFIA_CTX:-$(saufia::find_ctx)}"
export SAUFIA_CTX

# Source libs in deterministic order (alphabetical via glob is fine here
# because no lib depends on another lib's function at source-time)
for _f in "$SAUFIA_CTX"/lib/*/*.sh; do
  [[ -f "$_f" ]] && source "$_f"
done

# Load root config (global vars: MODEL, OLLAMA_URL, aliases...)
source "$SAUFIA_CTX/config"

# Load agent (calls scope::load internally, walks root->agent)
agent::load "${SAUFIA_AGENT:-default}"
