guard() {
  local code="$1" src="${2:-llm}" cfg="$SAUFIA_ROOT/conf"
  grep -qiE -f "$cfg/whitelist.reg" <<< "$code" && return 0
  grep -qiE -f "$cfg/blacklist.reg" <<< "$code" && { echo "GUARD: BLOCKED (blacklist)" >&2; return 1; }
  if [[ "$src" != "trusted" ]]; then
    grep -qiE -f "$cfg/edit_functions.reg" <<< "$code" && { echo "GUARD: BLOCKED (edit)" >&2; return 1; }
  fi
  local path
  while IFS= read -r path; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    grep -qE "(>|tee|cp|mv|install|chmod|chown)\s.*${path}" <<< "$code" && { echo "GUARD: BLOCKED path $path" >&2; return 1; }
  done < "$cfg/guard.paths"
  return 0
}
