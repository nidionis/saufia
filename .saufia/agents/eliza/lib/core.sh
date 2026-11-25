normalize() {
    local s="${1,,}"
    s="${s//[^a-z' ]/}"
    s="${s//  / }"
    echo "${s# }" | sed 's/ *$//'
}
compose() {
    local t="$1"
    local f="${CTX[focus]:-${CTX[mirror]}}"
    t="${t//\{X\}/$f}"
    t="${t//\{M\}/${CTX[mirror]}}"
    t="${t//\{I\}/${CTX[input]}}"
    local i
    for (( i=9; i>=0; i-- )); do
        [[ -n "${GRP[$i]:-}" ]] && t="${t//\{$i\}/$(reflect "${GRP[$i]}")}"
    done
    echo "${t^}"
}
pick_line() {
    local -a a=()
    while IFS= read -r l; do
        [[ -z "$l" || "$l" == \#* ]] && continue
        a+=("$l")
    done < "$1"
    echo "${a[$((RANDOM % ${#a[@]}))]}"
}
match() {
    local input="$1" f trig
    GRP=(); CTX[focus]=""
    for f in "$RULES"/*/trigger; do
        [[ -f "$f" ]] || continue
        while IFS= read -r trig; do
            [[ -z "$trig" || "$trig" == \#* ]] && continue
            if [[ "$input" =~ $trig ]]; then
                local i
                for i in "${!BASH_REMATCH[@]}"; do GRP[i]="${BASH_REMATCH[$i]}"; done
                local d; d="$(dirname "$f")"
                [[ -f "$d/bash" ]] && source "$d/bash"
                RESP="$(compose "$(pick_line "$d/prompt")")"
                return 0
            fi
        done < "$f"
    done
    return 1
}
loop() {
    local raw
    while true; do
        printf '%s' "$PROMPT"
        IFS= read -r raw || break
        local lc="${raw,,}"; lc="${lc// /}"
        [[ "$lc" =~ $EXIT_RE ]] && { bye; break; }
        CTX[input]="$(normalize "$raw")"
        CTX[mirror]="$(reflect "${CTX[input]}")"
        if match "${CTX[input]}"; then
            say "$RESP"
        else
            say "$(resort)"
        fi
    done
}
