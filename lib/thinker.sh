thinker() {
  local question="\$1" start="${2:-.}"
  start="$(cd "$start" && pwd)"
  local tid; tid=$(date +%s%N | tail -c 14)
  local tdir="$SAUFIA_THOUGHT_DIR/$tid"
  mkdir -p "$tdir"
  echo "$question" > "$tdir/question"
  ln -sfn "$tdir" "$SAUFIA_THOUGHT_DIR/last"
  local -a path=()
  local current="$start"
  while true; do
    local D="$current/$CONSOLID_DIR"
    [[ -d "$D" ]] || break
    local -a children=()
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      children+=("$(echo "$line" | sed 's/^ //')")
    done < "$D/subtree"
    local real_children=()
    for c in "${children[@]}"; do
      [[ "$c" == "$CONSOLID_DIR" ]] && continue
      real_children+=("$c")
    done
    if (( ${#real_children[@]} == 0 )); then
      path+=("$current")
      break
    fi
    local compare=""
    for c in "${real_children[@]}"; do
      local csum="$current/$c/$CONSOLID_DIR/summary"
      local ctxt="(no summary)"
      [[ -f "$csum" ]] && ctxt="$(cat "$csum")"
      compare+="$c: $ctxt"$'\n'
    done
    local choice
    choice=$(ask "Question: $question

Available branches (name: summary):
$compare

Reply with ONLY the branch name most relevant. Nothing else.")
    choice=$(echo "$choice" | tr -d '[:space:]')
    local found=0
    for c in "${real_children[@]}"; do
      [[ "$c" == "$choice" ]] && { found=1; break; }
    done
    (( found == 0 )) && choice="${real_children[0]}"
    path+=("$current/$choice")
    current="$current/$choice"
  done
  printf '%s\n' "${path[@]}" > "$tdir/path"
  local leaf="${path[-1]}" leafD="$leaf/$CONSOLID_DIR"
  local ctx=""
  [[ -f "$leafD/summary" ]] && ctx+="SUMMARY: $(cat "$leafD/summary")"$'\n'
  for r in code values citations; do
    [[ -s "$leafD/references/$r" ]] && ctx+="$(echo "$r" | tr 'a-z' 'A-Z'): $(cat "$leafD/references/$r")"$'\n'
  done
  local answer
  answer=$(ask "$ctx

QUESTION: $question")
  echo "$answer" > "$tdir/answer"
  echo "$answer"
}

thought_stack() {
  ls -1 "$SAUFIA_THOUGHT_DIR" 2>/dev/null | grep -v '^last$' | sort -rn
}
