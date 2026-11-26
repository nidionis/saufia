# prompt::fill <template-file-or-string> [input]
# Replaces {VAR} with the value of $VAR (any scope), {I} with input.
# Unknown placeholder -> removed. Guarded against self-expansion loops.
prompt::fill() {
  local t input="${2:-}"
  if [[ -f "$1" ]]; then t="$(cat "$1")"; else t="$1"; fi
  t="${t//\{I\}/$input}"
  local n guard=0
  while [[ "$t" =~ \{([A-Z][A-Z0-9_]*)\} ]] && (( guard++ < 64 )); do
    n="${BASH_REMATCH[1]}"
    t="${t//"${BASH_REMATCH[0]}"/${!n:-}}"
  done
  printf '%s\n' "$t"
}

# prompt::forbid — renders FORBIDDEN array as "No x. No y."
prompt::forbid() {
  local item line=""
  for item in "${FORBIDDEN[@]:-}"; do
    line+="No ${item}. "
  done
  printf '%s\n' "${line% }"
}
