# keytokens::scan_agent <DIR> <INPUT> — print "score name" if it matches. 1 loop.
keytokens::scan_agent() {
  local DIR="$1" INPUT="$2" AGENT="${2#"$CONTEXT/agents/"}" SCORE=0 TOK
  AGENT="${DIR#"$CONTEXT/agents/"}"; AGENT="${AGENT%/}"
  ( source "$CONTEXT/config" 2>/dev/null; source "$DIR/config" 2>/dev/null
    for TOK in "${KEYTOKENS[@]:-}"; do                  # single loop
      [[ "$INPUT" == *"${TOK,,}"* ]] && (( SCORE++ )) || true
    done
    (( SCORE > 0 )) && printf '%d %s\n' "$SCORE" "$AGENT" )
}

# keytokens::scan <INPUT> — list every agent dir, score each. 1 loop.
keytokens::scan() {
  local INPUT="${1,,}" DIR
  for DIR in "$CONTEXT"/agents/*/*/; do                 # single loop
    [[ -f "$DIR/config" ]] && keytokens::scan_agent "$DIR" "$INPUT"
  done | sort -rn
}

# keytokens::invite <FOLDER> [INPUT] — best agent fills folder digest. 0 loops.
keytokens::invite() {
  local FOLDER="$1" INPUT="${2:-}" BEST RESULT
  BEST="$(keytokens::scan "$INPUT" | head -1 | awk '{print $2}')"
  [[ -n "$BEST" ]] || { echo "keytokens::invite: no match" >&2; return 1; }
  echo "keytokens::invite: @$BEST -> $FOLDER" >&2
  agent::load "$BEST"
  RESULT="$(agent::ask "Fill context for: $FOLDER
Input: $INPUT
List key files, concepts, structure. Terse.")"
  printf '%s\n' "$RESULT" > "$FOLDER/$CONSOLIDATION_DIR"
  echo "$RESULT"
}

# keytokens::stack <INPUT> <FOLDERS...> — fill several folders. 1 loop.
keytokens::stack() {
  local INPUT="$1" FOLDER; shift
  for FOLDER in "$@"; do                                # single loop
    [[ -d "$FOLDER" ]] && keytokens::invite "$FOLDER" "$INPUT" || echo "keytokens: skip '$FOLDER'" >&2
  done
}

# keytokens::list — show every agent and its keytokens. 1 loop.
keytokens::list() {
  local DIR AGENT TOKENS
  for DIR in "$CONTEXT"/agents/*/*/; do                 # single loop
    [[ -f "$DIR/config" ]] || continue
    AGENT="${DIR#"$CONTEXT/agents/"}"; AGENT="${AGENT%/}"
    TOKENS="$(grep -oP 'KEYTOKENS=\(.*?\)' "$DIR/config" 2>/dev/null || echo '()')"
    printf '  @%-26s %s\n' "$AGENT" "$TOKENS"
  done
}
