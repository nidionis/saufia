guard::load() {
  [[ -n "${TIMEOUT+x}" ]] || { echo "guard: TIMEOUT unset" >&2; return 41; }
  [[ -n "${SANDBOX_DIR+x}" ]] || { echo "guard: SANDBOX_DIR unset" >&2; return 41; }
  mkdir -p "$SANDBOX_DIR"
}
