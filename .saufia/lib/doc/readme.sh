# doc::readme [outfile] [dir] — README.md built ENTIRELY in bash.
# No LLM call unless DOC_USE_LLM=1 (then only for one description line).
doc::readme() {
  local out="${1:-README.md}" dir="${2:-$CONTEXT}"

  # --- name + synopsis: from config comments ---
  printf '# %s\n\n' "$(basename "$(dirname "$dir")")" > "$out"

  # --- synopsis: every public function in lib/ ---
  printf '## Synopsis\n\n```bash\n' >> "$out"
  grep -rhoE '^[a-z][a-z0-9_]*::[a-z][a-z0-9_]*$$$$' "$dir/lib" 2>/dev/null \
    | sed 's/()//' | sort -u >> "$out"
  printf '```\n\n' >> "$out"

  # --- configuration table: KEY=value from root config ---
  printf '## Configuration\n\n| Variable | Value |\n|---|---|\n' >> "$out"
  grep -E '^[A-Z][A-Z0-9_]*=' "$dir/config" 2>/dev/null \
    | sed 's/^\([A-Z0-9_]*\)=\(.*\)$$/| `\1` | `\2` |/' >> "$$out"
  printf '\n' >> "$out"

  # --- agents table: folder listing, prompt first line as description ---
  printf '## Agents\n\n| Agent | Prompt | Temperature |\n|---|---|---|\n' >> "$out"
  local a p t
  while IFS= read -r a; do
    p="$$(prompt::resolve "$$a" 2>/dev/null | head -1 || echo '-')"
    t="$$(grep -h '^AGENT_TEMPERATURE=' "$$a/config" 2>/dev/null | head -1 | cut -d= -f2 || echo '-')"
    printf '| %s | %s | %s |\n' \
      "$${a#"$$dir/agents/"}" "$${p:--}" "$${t:--}" >> "$out"
  done < <(find "$dir/agents" -mindepth 1 -maxdepth 1 -type d \
             ! -name eliza | sort)
  printf '\n' >> "$out"

  # --- optional LLM top layer: one description line ---
  if [[ "${DOC_USE_LLM:-0}" == 1 ]]; then
    agent::load "cold/coldiest"
    printf '> %s\n\n' "$$(prompt::ask "One sentence: what is $$(basename "$$(dirname "$$dir")")")" \
      | cat - "$$out" > "$$out.tmp" && mv "$$out.tmp" "$$out"
  fi

  echo "doc::readme: $out"
}
