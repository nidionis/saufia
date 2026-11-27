#!/usr/bin/env bash
# factory::run — deterministic agent generator.
# stdin = "name [family] [type] [description...]"
# Or: echo "my-agent read deterministic parses CSV into markdown" | saufia @factory
set -euo pipefail

# ─── Parse input ───────────────────────────────────────────────
INPUT="$(cat)"
NAME="$(awk '{print $1}' <<< "$INPUT")"
FAMILY="$(awk '{print $2}' <<< "$INPUT")"
TYPE="$(awk '{print $3}' <<< "$INPUT")"
DESC="$(awk '{$1=$2=$3=""; print substr($0,4)}' <<< "$INPUT")"

# Defaults from config (scope::load already sourced them)
FAMILY="${FAMILY:-${FACTORY_DEFAULT_FAMILY:-tool}}"
TYPE="${TYPE:-${FACTORY_DEFAULT_TYPE:-deterministic}}"
DESC="${DESC:-$NAME}"

# Validate
case "$FAMILY" in read|exec|dev|chat|tool|doc) ;; *) FAMILY="$FACTORY_DEFAULT_FAMILY" ;; esac
case "$TYPE" in deterministic|llm|hybrid) ;; *) TYPE="$FACTORY_DEFAULT_TYPE" ;; esac

[[ -n "$NAME" ]] || { echo "factory: usage: <name> [family] [type] [description]" >&2; exit 1; }

DIR="${FACTORY_ROOT:-.}/$FAMILY/$NAME"
[[ -d "$DIR" ]] && { echo "factory: '$FAMILY/$NAME' already exists" >&2; exit 1; }

# ─── Scaffold ──────────────────────────────────────────────────
mkdir -p "$DIR"

# Config: always generated. Type determines what goes in.
case "$TYPE" in
  deterministic)
    cat > "$DIR/config" <<CFG
# Deterministic agent. No LLM. scripts/run.sh is the entire behavior.
AGENT_NO_AI=1
KEYTOKENS=($(echo "$DESC" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs -n1 | head -6 | tr '\n' ' ' | sed 's/ /"/g;s/^/"/;s/ $/"\)/;s/)$/"\)/'))
CFG
    ;;
  llm)
    cat > "$DIR/config" <<CFG
# LLM agent. prompt drives behavior. No script.
AGENT_TEMPERATURE=\$COLD
AGENT_NUM_PREDICT=\$GATHA_SIZE
KEYTOKENS=($(echo "$DESC" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs -n1 | head -6 | tr '\n' ' ' | sed 's/ /"/g;s/^/"/;s/ $/"\)/;s/)$/"\)/'))
CFG
    ;;
  hybrid)
    cat > "$DIR/config" <<CFG
# Hybrid: script handles structure, LLM refines output.
# Set DOC_USE_LLM=1 to activate the LLM layer.
AGENT_TEMPERATURE=\$COLD
AGENT_NUM_PREDICT=\$GATHA_SIZE
DOC_USE_LLM=0
KEYTOKENS=($(echo "$DESC" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs -n1 | head -6 | tr '\n' ' ' | sed 's/ /"/g;s/^/"/;s/ $/"\)/;s/)$/"\)/'))
CFG
    ;;
esac

# Prompt: only for llm and hybrid types.
if [[ "$TYPE" == "llm" || "$TYPE" == "hybrid" ]]; then
  cat > "$DIR/prompt" <<PRM
You are $NAME. $DESC
Shortest correct answer. No preamble.
PRM
fi

# Script: only for deterministic and hybrid types.
if [[ "$TYPE" == "deterministic" || "$TYPE" == "hybrid" ]]; then
  mkdir -p "$DIR/scripts"
  cat > "$DIR/scripts/run.sh" <<SCR
#!/usr/bin/env bash
# $NAME — $DESC
# stdin = input. stdout = output. Exit 0 = success.
# Replace the body below with real logic.
input="\$(cat)"
# TODO: implement "$DESC"
printf '%s\n' "\$input"
SCR
  chmod +x "$DIR/scripts/run.sh"
fi

# ─── Report ────────────────────────────────────────────────────
echo "factory: created $FAMILY/$NAME ($TYPE)"
echo "  dir:    $DIR"
[[ -f "$DIR/config" ]]  && echo "  config: $DIR/config"
[[ -f "$DIR/prompt" ]]  && echo "  prompt: $DIR/prompt"
[[ -x "$DIR/scripts/run.sh" ]] && echo "  script: $DIR/scripts/run.sh"
echo "  test:   echo 'hello' | saufia @$NAME"
