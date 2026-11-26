guard::check() {
  local code="$1" rx="$CONTEXT/tools/regexes"
  grep -qiE -f "$rx/whitelist.reg" <<< "$code" && return 0
  grep -qiE -f "$rx/blacklist.reg" <<< "$code" && {
    echo "guard: DENIED" >&2; return 1; }
  local p
  [[ -s "$rx/guard.paths" ]] || return 0
  while IFS= read -r p; do
    [[ -z "$p" || "$p" == \#* ]] && continue
    grep -qE "(>|tee|cp|mv|install|chmod|chown)\s.*${p}" <<< "$code" && {
      echo "guard: DENIED path $p" >&2; return 1; }
  done < "$rx/guard.paths"
}
