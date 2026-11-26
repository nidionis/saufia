# install::repo — resolve the package manager. REPO_SELECT wins if set.
install::repo() {
  case "${REPO_SELECT:-auto}" in
    auto)
      local MGR
      for MGR in dnf apt-get pacman zypper brew; do
        command -v "$MGR" >/dev/null 2>&1 && { printf '%s\n' "$MGR"; return 0; }
      done
      echo "install::repo: no known package manager (set REPO_SELECT)" >&2
      return 1 ;;
    *) printf '%s\n' "$REPO_SELECT" ;;
  esac
}

# install::need <binary> <package> — install only if the binary is absent.
install::need() {
  local BIN="$1" PKG="${2:-$1}" MGR ARGS
  command -v "$BIN" >/dev/null 2>&1 && return 0

  if [[ "${REPO_SELECT:-auto}" == go && "$BIN" == glow ]]; then
    command -v go >/dev/null 2>&1 || { echo "install::need: go missing" >&2; return 1; }
    echo "install::need: go install glow (charmbracelet/glow)" >&2
    go install github.com/charmbracelet/glow@latest
    return $?
  fi

  MGR="$(install::repo)" || return 1
  case "$MGR" in
    dnf)     ARGS="install -y $PKG" ;;
    apt-get) ARGS="install -y $PKG" ;;
    pacman)  ARGS="-S --noconfirm --needed $PKG" ;;
    zypper)  ARGS="--non-interactive install $PKG" ;;
    brew)    ARGS="install $PKG" ;;
    *) echo "install::need: unsupported repo '$MGR'" >&2; return 1 ;;
  esac

  # root only when the target actually needs it
  local SUDO=""
  [[ $EUID -ne 0 && -n "$(command -v sudo)" && "${INSTALL_ASSUME_YES:-1}" == 1 ]] && SUDO="sudo"

  echo "install::need: $BIN missing -> $SUDO $MGR $ARGS" >&2
  $SUDO "$MGR" $ARGS
}
