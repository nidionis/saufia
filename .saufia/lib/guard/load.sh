# guard::abs <path> — absolute path anchored at DOT_ROOT.
guard::abs() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$DOT_ROOT" "$1" ;;
  esac
}

# guard::root — directory the current agent may touch (canonical).
guard::root() {
  local root
  root="$(guard::abs "${AGENT_ROOT:-$DOT_ROOT}")"
  realpath -m -- "$root" 2>/dev/null || printf '%s\n' "$root"
}

# guard::load [exec|edit] — environment + privilege gate.
guard::load() {
  local mode="${1:-exec}"
  [[ -n "${TIMEOUT+x}" ]] || { echo "guard: TIMEOUT unset" >&2; return 41; }
  [[ -n "${SANDBOX_DIR+x}" ]] || { echo "guard: SANDBOX_DIR unset" >&2; return 41; }

  case "$mode" in
    exec)
      [[ "${AGENT_CAN_EXEC:-0}" == "1" ]] || {
        echo "guard: DENIED — '${AGENT_NAME:-?}' (${AGENT_ACTION:-?}) has no exec privilege" >&2
        return 1
      }
      ;;
    edit)
      [[ "${AGENT_CAN_EDIT:-0}" == "1" ]] || {
        echo "guard: DENIED — '${AGENT_NAME:-?}' (${AGENT_ACTION:-?}) has no edit privilege" >&2
        return 1
      }
      ;;
    *)
      echo "guard: unknown mode '$mode'" >&2
      return 1
      ;;
  esac

  SANDBOX_DIR="$(guard::abs "$SANDBOX_DIR")"
  export SANDBOX_DIR
  mkdir -p "$SANDBOX_DIR" "$(guard::root)"
}

# guard::path_ok <path> — path must stay inside AGENT_ROOT.
guard::path_ok() {
  local path="$1" root abs
  root="$(guard::root)"
  abs="$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")"
  [[ "$abs" == "$root" || "$abs" == "$root/"* ]]
}

guard::check_path() {
  guard::path_ok "$1" || {
    echo "guard: DENIED path '$1' outside $(guard::root)" >&2
    return 1
  }
}
