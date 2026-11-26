# doc::make <topic> [format] — pipeline: classer>summarize>owto>note>formator
doc::ask_step() {
  local agent="$1" input="$2"
  agent::load "$agent"
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    prompt::ask "$input"
  else
    printf '%s\n' "$input"
  fi
}

doc::make() {
  local topic="$1" fmt="${2:-md}"
  local scratch
  scratch="$(mktemp -d "${CONTEXT:-.}/.state/doc.XXXXXX")"

  doc::ask_step "classer"   "$topic"                    > "$scratch/class"
  doc::ask_step "summarize" "$(cat "$scratch/class")"   > "$scratch/sum"
  doc::ask_step "owto"      "$topic"                    > "$scratch/how"
  doc::ask_step "note"      "$(cat "$scratch/sum")"     > "$scratch/note"

  local heap
  heap="$(cat "$scratch/class" "$scratch/sum" "$scratch/how" "$scratch/note")"

  agent::load "formator"
  FILETYPE="$fmt" prompt::ask "$heap"
  rm -rf "$scratch"
}
