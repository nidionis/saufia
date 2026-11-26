# doc::make <topic> [format] — pipeline: classer>summarize>owto>note>formator
# Each step is prompt::ask (template filled by bash); LLM only if DOC_USE_LLM=1.
doc::ask_step() {  # <agent> <input>
  agent::load "\$1"
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    prompt::ask "\$2"
  else
    printf '%s\n' "\$2"   # passthrough: pipeline still composes context
  fi
}

doc::make() {
  local topic="\$1" fmt="${2:-md}"
  local scratch; scratch="$(mktemp -d "$CONTEXT/.state/doc.XXXXXX")"

  doc::ask_step "classer"   "$topic"           > "$scratch/class"
  doc::ask_step "summarize" "$(cat "$scratch/class")" > "$scratch/sum"
  doc::ask_step "owto"      "$topic"           > "$scratch/how"
  doc::ask_step "note"      "$(cat "$scratch/sum")"   > "$scratch/note"

  # heap = accumulated context; stack order preserved by cat order
  local heap; heap="$(cat "$scratch/class" "$scratch/sum" "$scratch/how" "$scratch/note")"

  agent::load "formator"
  FILETYPE="$fmt" prompt::ask "$heap"
  rm -rf "$scratch"
}
