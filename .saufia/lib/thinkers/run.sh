thinker::run() {
  local question="\$1" start; start="$(cd "${2:-.}" && pwd)"
  local tid; tid="$(date +%s%N | tail -c 14)"
  local state="$SAUFIA_CTX/digest/.state/$tid"
  mkdir -p "$state"
  echo "$question" > "$state/question"
  ln -sfn "$state" "$SAUFIA_CTX/digest/.state/last"

  local current="$start" ctx=""
  while true; do
    [[ -f "$current/$DIGEST_DIR" ]] && ctx+="[$current] $(cat "$current/$DIGEST_DIR")"$'\n'

    local -a kids=()
    while IFS= read -r -d '' d; do
      [[ -f "$d/$DIGEST_DIR" ]] && kids+=("$d")
    done < <(find "$current" -maxdepth 1 -mindepth 1 -type d \
      ! -name .git ! -name node_modules -print0 2>/dev/null)
    (( ${#kids[@]} == 0 )) && break

    local list="" k
    for k in "${kids[@]}"; do
      list+="$(basename "$k"): $(cat "$k/$DIGEST_DIR")"$'\n'
    done
    local pick
    pick="$(agent::ask "Question: $question
Children:
$list
Reply ONLY the folder name most relevant." | tr -d '[:space:]')"

    local found=0
    for k in "${kids[@]}"; do
      [[ "$(basename "$k")" == "$pick" ]] && { current="$k"; found=1; break; }
    done
    (( found == 0 )) && break
  done

  local answer
  answer="$(agent::ask "$ctx
QUESTION: $question")"
  echo "$answer" > "$state/answer"
  echo "$answer"
}
