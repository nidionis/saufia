_cfg="${SAUFIA_CONF:-${SAUFIA_SVR_ROOT:-$HOME/.svr}/saufia/conf/global.conf}"
[[ -f "$_cfg" ]] && source "$_cfg"
export SAUFIA_CONF="$_cfg"
for _lib in "$SAUFIA_ROOT"/lib/{ollama,agent,guard,executor,tokenize,digest,search,thinker}.sh; do
  [[ -f "$_lib" ]] && source "$_lib"
done
load_agent "${SAUFIA_AGENT:-$DEFAULT_AGENT}"
