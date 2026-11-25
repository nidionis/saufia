coder::run() {
  local problem="$1" dir="${2:-.}"
  agent::load "coder"
  local code
  code="$(agent::ask "$problem
Context dir: $dir
Output ONLY code in a fenced block.")"
  guard::exec "$code"
}
