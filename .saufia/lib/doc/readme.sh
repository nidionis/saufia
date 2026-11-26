# doc::readme [outfile] [dir] — README.md built entirely in bash.
# LLM only decorates the description when DOC_USE_LLM=1.
doc::readme() {
  local OUT="${1:-README.md}" DIR="${2:-$CONTEXT}" DESC

  printf '# %s\n\n' "$(basename "$DIR")" > "$OUT"

  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    agent::load "cold/coldiest"
    DESC="$(prompt::ask "One sentence: what is $(basename "$DIR")")"
    printf '> %s\n\n' "$DESC" >> "$OUT"
  fi

  # Synopsis: every public verb in lib/
  printf '## Synopsis\n\n```bash\n' >> "$OUT"
  grep -rhoE '^[a-z][a-z0-9_]*::[a-z][a-z0-9_]*$' "$DIR/lib" 2>/dev/null \
    | sed 's/()//' | sort -u >> "$OUT" || true
  printf '```\n\n' >> "$OUT"

  # Configuration table from the root config
  printf '## Configuration\n\n| Variable | Value |\n|---|---|\n' >> "$OUT"
  grep -E '^[A-Z][A-Z0-9_]*=' "$DIR/config" 2>/dev/null \
    | sed 's/^\([A-Z0-9_]*\)=\(.*\)$/| `\1` | `\2` |/' >> "$OUT" || true
  printf '\n' >> "$OUT"

  # Agents table: path + first prompt line + temperature
  printf '## Agents\n\n| Agent | Prompt | Temp |\n|---|---|---|\n' >> "$OUT"
  local NAME PROMPT_LINE TEMP
  while IFS= read -r NAME; do
    PROMPT_LINE="$(head -1 "$DIR/agents/$NAME/prompt" 2>/dev/null || true)"
    TEMP="$(grep -h '^AGENT_TEMPERATURE=' "$DIR/agents/$NAME/config" 2>/dev/null | head -1 | cut -d= -f2 || true)"
    printf '| %s | %s | %s |\n' "$NAME" "${PROMPT_LINE:--}" "${TEMP:--}" >> "$OUT"
  done < <(agent::list "$DIR/agents")
  printf '\n' >> "$OUT"

  echo "doc::readme: $OUT"
}
