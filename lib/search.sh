search() {
  local root="${SEARCH_ROOT:-.}" q_tokens
  q_tokens=$(echo "$*" | tokenize)
  local -A scores=()
  while IFS= read -r -d '' dic; do
    local folder; folder="$(dirname "$(dirname "$dic")")"
    local tok file
    while IFS=$'\t' read -r tok file; do
      [[ -z "$tok" ]] && continue
      grep -qxF "$tok" <<< "$q_tokens" && scores["$folder/$file"]=$(( ${scores["$folder/$file"]:-0} + 1 ))
    done < "$dic"
  done < <(find "$root" -path "*/$CONSOLID_DIR/dictionary" -print0 2>/dev/null)
  local top=$(( ${#scores[@]} * CONTEXT_RATIO / 100 )); (( top < 1 )) && top=1
  for f in "${!scores[@]}"; do echo "${scores[$f]} $f"; done | sort -rn | head -n "$top"
}
