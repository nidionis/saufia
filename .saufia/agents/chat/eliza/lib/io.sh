banner() { echo "  ELIZA — 5-word grammar"; echo "$GREETING"; echo; }
say()     { echo; echo "  $1"; echo; }
bye()     { local IFS='|'; local a=($FAREWELL); echo; echo "  ${a[$((RANDOM % ${#a[@]}))]}"; echo; }
resort()  { compose "$(pick_line "$RULES/fallback/prompt")"; }
