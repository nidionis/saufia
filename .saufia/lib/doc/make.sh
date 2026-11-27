# doc::make [format] — pipeline: classer > summarize > howto > note > formator
doc::ask_step() {
  local agent="$1" input="$2"
  agent::load "$agent" || return 1
  agent::ask_if_llm "$input"
}
doc::make() {
  local topic="$1" fmt="${2:-md}"
  local scratch
  scratch="$(mktemp -d "${CONTEXT:-.}/.state/doc.XXXXXX")"
  doc::ask_step "read/text/classer" "$topic" > "$scratch/class"
  doc::ask_step "read/text/summarize" "$(cat "$scratch/class")" > "$scratch/sum"
  doc::ask_step "read/q/howto" "$topic" > "$scratch/how"
  doc::ask_step "read/text/note" "$(cat "$scratch/sum")" > "$scratch/note"
  local heap
  heap="$(cat "$scratch/class" "$scratch/sum" "$scratch/how" "$scratch/note")"
  agent::load "read/text/formator" || return 1
  FILETYPE="$fmt" prompt::ask "$heap"
  rm -rf "$scratch"
}
