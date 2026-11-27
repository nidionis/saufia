#!/usr/bin/env bash
set -uo pipefail
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; ITALIC=$'\e[3m'; RESET=$'\e[0m'
  H1=$'\e[1;95m'; H2=$'\e[1;94m'; H3=$'\e[1;96m'; H4=$'\e[1;33m'
  CODE_BG=$'\e[48;5;236m'; CODE_FG=$'\e[38;5;203m'
  LINK=$'\e[4;94m'; HR=$'\e[2;90m'; BULLET=$'\e[1;93m'
else
  BOLD=""; DIM=""; ITALIC=""; RESET=""; H1=""; H2=""; H3=""; H4=""
  CODE_BG=""; CODE_FG=""; LINK=""; HR=""; BULLET=""
fi
WIDTH="${COLUMNS:-80}"
inline() {
  local s="$1"
  s="${s//\`\`${CODE_BG}${CODE_FG}}"; s="${s//\`\`/$RESET}"
  s="$(printf '%s' "$s" | sed -E 's/\*\*\*(.+?)\*\*\*/'"${BOLD}${ITALIC}"'\1'"${RESET}"'/g')"
  s="$(printf '%s' "$s" | sed -E 's/\*\*(.+?)\*\*/'"${BOLD}"'\1'"${RESET}"'/g')"
  s="$(printf '%s' "$s" | sed -E 's/\*([^*]+)\*/'"${ITALIC}"'\1'"${RESET}"'/g')"
  s="$(printf '%s' "$s" | sed -E 's/_([^_]+)_/'"${ITALIC}"'\1'"${RESET}"'/g')"
  s="$(printf '%s' "$s" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/'"${LINK}"'\1'"${RESET}${DIM}"' (\2)'"${RESET}"'/g')"
  s="$(printf '%s' "$s" | sed -E 's/~~(.+?)~~/'"${DIM}"'\1'"${RESET}"'/g')"
  printf '%s' "$s"
}
main() {
IN_CODE=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^\`\`\` ]]; then
    if (( IN_CODE )); then printf '%s\n' "${RESET}${DIM}└──${RESET}"; IN_CODE=0
    else printf '%s┌── %s%s\n' "${DIM}" "${line#\`\`\`}" "${RESET}"; IN_CODE=1; fi
    continue
  fi
  if (( IN_CODE )); then printf '  %s%s%s\n' "${CODE_BG}${CODE_FG}" "$line" "${RESET}"; continue; fi
  if [[ "$line" =~ ^[\*-]{3,}$ ]] || [[ "$line" =~ ^_{3,}$ ]]; then
    printf '%s%s%s\n' "$HR" "$(printf '%*s' "$WIDTH" '' | sed 's/ /─/g')" "$RESET"; continue; fi
  if [[ "$line" =~ ^(#{1,6})\ (.*) ]]; then
    local level="${#BASH_REMATCH[1]}" text="${BASH_REMATCH[2]}"
    text="$(inline "$text")"
    case $level in
      1) printf '\n%s%s%s\n%s%s%s\n' "$H1" "$text" "$RESET" "$HR" "$(printf '%*s' "${#BASH_REMATCH[2]}" '' | sed 's/ /═/g')" "$RESET" ;;
      2) printf '\n%s%s%s\n' "$H2" "$text" "$RESET" ;;
      3) printf '\n  %s%s%s\n' "$H3" "$text" "$RESET" ;;
      4) printf '\n    %s%s%s\n' "$H4" "$text" "$RESET" ;;
      *) printf '\n      %s%s%s\n' "${BOLD}" "$text" "$RESET" ;;
    esac
    continue
  fi
  if [[ "$line" =~ ^\>\ ?(.*) ]]; then
    printf '%s│%s %s\n' "${DIM}" "${RESET}" "$(inline "${BASH_REMATCH[1]}")"; continue; fi
  if [[ "$line" =~ ^(\ *)([-*+])\ (.*) ]]; then
    local pad; pad="$(printf '%*s' "${#BASH_REMATCH[1]}" '')"
    printf '%s  %s•%s %s\n' "$pad" "$BULLET" "$RESET" "$(inline "${BASH_REMATCH[3]}")"; continue; fi
  if [[ "$line" =~ ^(\ *)([0-9]+)\.\ (.*) ]]; then
    local pad; pad="$(printf '%*s' "${#BASH_REMATCH[1]}" '')"
    printf '%s  %s%s.%s %s\n' "$pad" "${BOLD}" "${BASH_REMATCH[2]}" "$RESET" "$(inline "${BASH_REMATCH[3]}")"; continue; fi
  if [[ "$line" =~ ^\|(.+)\|$ ]]; then
    local content="${BASH_REMATCH[1]}"
    if [[ "$content" =~ ^[-:\ |]+$ ]]; then
      printf '%s%s%s\n' "$HR" "$(printf '%*s' "$WIDTH" '' | sed 's/ /─/g')" "$RESET"; continue; fi
    local IFS='|'; local -a cells; read -ra cells <<< "$content"; local row="" cell
    for cell in "${cells[@]}"; do cell="${cell# }"; cell="${cell% }"
      row+="${BOLD}$(inline "$cell")${RESET}  "; done
    printf '  %s\n' "$row"; continue
  fi
  if [[ -z "${line// /}" ]]; then printf '\n'; continue; fi
  printf '%s\n' "$(inline "$line")"
done
(( IN_CODE )) && printf '%s\n' "${RESET}"
}
main
