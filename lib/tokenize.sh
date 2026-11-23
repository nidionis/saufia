tokenize() {
  tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' \
    | grep -E "^.{${TOKEN_MIN_LEN},}$" | sort -u
}
