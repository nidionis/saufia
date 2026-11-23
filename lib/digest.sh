digest_dir() {
  local dir="\$1" D="\$1/$CONSOLID_DIR"
  mkdir -p "$D/references"
  local -a files=() ext_args=() e
  for e in $SAUFIA_EXTS; do ext_args+=(-o -name "*.$e"); done
  while IFS= read -r -d '' f; do files+=("$f"); done \
    < <(find "$dir" -maxdepth 1 -type f $ "${ext_args[@]:1}" $ -print0 2>/dev/null)
  local subtree
  subtree=$(find "$dir" -maxdepth 1 -mindepth 1 -type d \
    ! -name "$CONSOLID_DIR" ! -name .git ! -name node_modules -printf ' %P\n' 2>/dev/null)
  if (( ${#files[@]} == 0 )); then
    printf '%s\n' "${subtree:- (no subdirs)}" > "$D/subtree"
    echo "(empty)" > "$D/summary"; : > "$D/dictionary"
    for r in code values citations; do : > "$D/references/$r"; done
    echo " .digest $dir (empty)"; return
  fi
  local blob="" f sz
  for f in "${files[@]}"; do
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    (( sz > MAX_FILE_SIZE )) && continue
    blob+="=== $(basename "$f") ==="$'\n'"$(head -c "$MAX_FILE_SIZE" "$f")"$'\n\n'
  done
  local out
  out=$(ask "Analyze. Output EXACTLY 4 lines, no markdown:
SUMMARY: <2 sentences>
CODE: <key functions/classes>
VALUES: <constants, configs>
CITATIONS: <file:line refs>
$blob")
  awk '/^SUMMARY:/{sub(/^SUMMARY: ?/,"");print > "'"$D"'/summary"}
       /^CODE:/{sub(/^CODE: ?/,"");print > "'"$D"'/references/code"}
       /^VALUES:/{sub(/^VALUES: ?/,"");print > "'"$D"'/references/values"}
       /^CITATIONS:/{sub(/^CITATIONS: ?/,"");print > "'"$D"'/references/citations"}' <<< "$out"
  [[ -s "$D/summary" ]] || echo "(no summary)" > "$D/summary"
  for r in code values citations; do [[ -s "$D/references/$r" ]] || : > "$D/references/$r"; done
  : > "$D/dictionary"
  for f in "${files[@]}"; do
    tokenize < "$f" | while read -r tok; do printf '%s\t%s\n' "$tok" "$(basename "$f")"; done >> "$D/dictionary"
  done
  printf '%s\n' "${subtree:- (no subdirs)}" > "$D/subtree"
  echo " .digest $dir (${#files[@]} files)"
}

digest() {
  local target; target="$(cd "${1:-.}" && pwd)"
  echo "digest: $target"
  while IFS= read -r -d '' d; do digest_dir "$d"; done \
    < <(find "$target" $ -name .git -o -name node_modules -o -name "$CONSOLID_DIR" $ -prune -o -type d -print0)
  echo "done."
}

digest_clean() {
  local dir; dir="$(cd "${1:-.}" && pwd)"
  find "$dir" -type d -name "$CONSOLID_DIR" -prune -exec rm -rf {} + 2>/dev/null
  echo "cleaned under $dir"
}
