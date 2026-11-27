# llm::strip_think — strip model reasoning/thinking blocks from LLM answers.
# Reads the answer from stdin, writes the cleaned answer to stdout.
llm::strip_think() {
  awk '
    BEGIN { strip = 0 }
    {
      if (strip) {
        if ($0 ~ /^```/ || $0 ~ /<\/thinking>/) { strip = 0 }
        next
      }
      if ($0 ~ /^```thinking/ || $0 ~ /^<thinking/ || $0 ~ /^\[?thinking/) {
        strip = 1
        if ($0 ~ /<\/thinking>/) { strip = 0 }
        next
      }
      print $0
    }
  '
}
