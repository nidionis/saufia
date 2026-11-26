# tokenize::run — stdin -> lowercase alnum tokens, min length, deduped
tokenize::run() {
  tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '\n' \
    | grep -E "^.{$${TOKEN_SIZE_MIN:-3},}$$" \
    | sort -u
}
