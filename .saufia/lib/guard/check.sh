# guard::check <code> — blacklist first, whitelist early-allow, protected paths.
guard::check() {
  local code="$1" rx="${GUARD_RX_DIR:-$CONTEXT/tools/regexes}" p
  if [[ -s "$rx/blacklist.reg" ]] \
     && grep -qiE -f "$rx/blacklist.reg" <<< "$code"; then
    echo "guard: DENIED" >&2
    return 1
  fi
  if [[ -s "$rx/whitelist.reg" ]] \
     && grep -qiE -f "$rx/whitelist.reg" <<< "$code"; then
    return 0
  fi
  [[ -s "$rx/guard.paths" ]] || return 0
  while IFS= read -r p; do
    [[ -z "$p" || "$p" == \#* ]] && continue
    grep -qE "(>|tee|cp|mv|install|chmod|chown)\s.*${p}" <<< "$code" && {
      echo "guard: DENIED path $p" >&2
      return 1
    }
  done < "$rx/guard.paths"
}

# guard::readonly <cmd> [args...] — strict read-only allowlist for @bot.
guard::readonly() {
  local cmd="$1"; shift || true
  local rx="${GUARD_RX_DIR:-$CONTEXT/tools/regexes}" line="$cmd" a
  for a in "$@"; do line+=" $a"; done

  if [[ -s "$rx/blacklist.reg" ]] \
     && grep -qiE -f "$rx/blacklist.reg" <<< "$line"; then
    echo "guard: DENIED (blacklist)" >&2
    return 1
  fi
  if grep -qE '[;&|<>`$(){}]' <<< "$line"; then
    echo "guard: DENIED (shell metacharacters)" >&2
    return 1
  fi
  if [[ -s "$rx/whitelist.reg" ]] \
     && ! grep -qiE -f "$rx/whitelist.reg" <<< "$line"; then
    echo "guard: DENIED (not read-only)" >&2
    return 1
  fi
  return 0
}
