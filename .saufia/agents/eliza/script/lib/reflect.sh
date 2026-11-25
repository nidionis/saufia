reflect() {
    local s=" $1 " src dst
    while IFS=$"\t" read -r src dst; do
        [[ -z "$src" || "$src" == \#* ]] && continue
        s="${s// $src / $dst }"
    done < "$PRONOUNS"
    echo "${s# }" | sed "s/ *\$//"
}
