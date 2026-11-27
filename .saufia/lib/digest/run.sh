digest::start() {
  local INTERVAL="${1:-${DIGEST_INTERVAL:-60}}"
  local BRANCH="${DIGEST_BRANCH:-digest}"
  local ROOT="${DIGEST_ROOT:-$DOT_ROOT}"
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "digest: not a git repo ($ROOT)" >&2; return 1; }
  local ORIG_BRANCH
  ORIG_BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null \
    || git -C "$ROOT" branch "$BRANCH" 2>/dev/null
  echo "digest: started (interval=${INTERVAL}s, branch=$BRANCH)"
  ( trap 'echo "digest: stopped"; exit 0' TERM INT
    while true; do sleep "$INTERVAL"; digest::tick "$ROOT" "$BRANCH" "$ORIG_BRANCH"; done ) &
  echo $! > "$CONTEXT/.state/digest.pid"
  echo "digest: pid $(cat "$CONTEXT/.state/digest.pid")"
}
digest::tick() {
  local ROOT="$1" BRANCH="$2" BASE="$3"
  local GIT="git -C $ROOT"
  local STASHED=0
  if ! $GIT diff --quiet 2>/dev/null; then
    $GIT stash push -m "digest-auto" --quiet 2>/dev/null && STASHED=1; fi
  $GIT checkout "$BRANCH" --quiet 2>/dev/null || {
    [[ $STASHED -eq 1 ]] && $GIT stash pop --quiet 2>/dev/null; return 1; }
  consolidation::run "$ROOT" 2>/dev/null
  find "$ROOT" -name "$CONSOLIDATION_DIR" -newer "$CONTEXT/.state/digest.last" \
    -exec $GIT add {} \; 2>/dev/null
  if ! $GIT diff --cached --quiet 2>/dev/null; then
    $GIT commit -m "digest: $(date +%Y-%m-%dT%H:%M:%S)" --quiet 2>/dev/null
    echo "digest: committed $(date +%H:%M:%S)" >&2; fi
  touch "$CONTEXT/.state/digest.last"
  $GIT checkout "$BASE" --quiet 2>/dev/null
  [[ $STASHED -eq 1 ]] && $GIT stash pop --quiet 2>/dev/null
}
digest::stop() {
  local PIDFILE="$CONTEXT/.state/digest.pid"
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null && echo "digest: stopped" \
      || echo "digest: process already dead"; rm -f "$PIDFILE"
  else echo "digest: not running"; fi
}
digest::status() {
  local PIDFILE="$CONTEXT/.state/digest.pid"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "digest: running (pid $(cat "$PIDFILE"))"; else echo "digest: stopped"; fi
}
digest::merge() {
  local BRANCH="${DIGEST_BRANCH:-digest}" ROOT="${DIGEST_ROOT:-$DOT_ROOT}"
  local GIT="git -C $ROOT" BASE
  BASE="$($GIT rev-parse --abbrev-ref HEAD)"
  echo "=== diff $BASE..$BRANCH ==="; $GIT diff "$BASE".."$BRANCH" --stat; echo
  read -rp "Merge $BRANCH into $BASE? [y/N] " REPLY
  if [[ "${REPLY,,}" == "y" ]]; then $GIT merge "$BRANCH" --no-edit; echo "digest: merged"
  else echo "digest: not merged"; fi
}
