# doc::man <topic> — softcoded man maker
doc::man() {
  agent::load "man"
  prompt::ask "\$1"
}
