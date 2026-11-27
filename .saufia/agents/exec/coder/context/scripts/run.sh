#!/usr/bin/env bash
# stdin = prompt text. Optional last arg = dir (if it's a valid dir).
# Gathers .digest + file list, prepends to the question.
input="$(cat)"
dir="."
# If last word is an existing directory, use it as context dir.
last="${input##* }"
[[ -d "$last" ]] && { dir="$last"; input="${input% $last}"; }
ctx=""
[[ -f "$dir/$CONSOLIDATION_DIR" ]] && ctx+="[$dir] $(cat "$dir/$CONSOLIDATION_DIR")"$'\n'
ctx+="files: $(find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | tr '\n' ' ')"
printf '%s\n%s\n' "$ctx" "$input"
