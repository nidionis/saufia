# find::var — extract all ${VAR} references from a string. 0 loops.
# find::has — true if string contains a ${VAR} reference. 0 loops.
# find::keys — extract all KEY= names from config text. 0 loops.

FIND_VAR_RE='\$\{([A-Za-z_][A-Za-z0-9_]*)\}'
FIND_ASSIGN_RE='^([A-Z][A-Z0-9_]*)='

find::var() { grep -oP "$FIND_VAR_RE" <<< "$1" | tr -d '${}'; }
find::has() { grep -qP "$FIND_VAR_RE" <<< "$1"; }
find::keys() { grep -oP "$FIND_ASSIGN_RE" <<< "$1" | tr -d '='; }
find::softcoded() { grep -oP '\$\{[A-Z][A-Z0-9_]*\}' <<< "$1" | tr -d '${}'; }
