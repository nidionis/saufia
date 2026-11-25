# Self-locating: no absolute path is ever baked into the tree.
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

for _f in "$SAUFIA_CTX"/lib/*/*.sh; do
  [[ -f "$_f" ]] && source "$_f"
done

scope::load "$SAUFIA_CTX"
agent::load "${SAUFIA_AGENT:-default}"
