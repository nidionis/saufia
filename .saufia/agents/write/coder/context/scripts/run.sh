#!/usr/bin/env bash
# stdin = "<question> [dir]". Gather .digest + file list from dir,
# prepend to the question, hand the whole thing to the coder LLM.
read -r line
q="${line%% *}"; dir="${line#* }"; dir="${dir:-.}"
ctx=""
[[ -f "$dir/$CONSOLIDATION_DIR" ]] && ctx+="[$dir] $(cat "$dir/$CONSOLIDATION_DIR")"$'\n'
ctx+="files: $(find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | tr '\n' ' ')"
printf '%s\n%s\n' "$ctx" "$q"
