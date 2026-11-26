#!/bin/bash

# ─────────────────────────────────────────
# USAGE:
#   ./rclone-bisync.sh <remote-name>
#   e.g. ./rclone-bisync.sh Gdrive-1
#        ./rclone-bisync.sh Gdrive-2
#
# One script, reused for every remote. Each remote
# gets its OWN lock file (derived from its name), so
# Gdrive-1 and Gdrive-2 can sync fully concurrently
# without blocking each other -- while each remote
# still can't run twice against itself at once.
# ─────────────────────────────────────────

REMOTE_NAME="$1"   # must match a remote name in rclone.conf, e.g. "Gdrive-1"

if [ -z "$REMOTE_NAME" ]; then
  echo "Usage: $0 <remote-name>"
  exit 1
fi

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
NOTIFY=false

# Local sync folder -- assumes a convention like
# ~/Gdrive-1, ~/Gdrive-2. Change if yours differs.
LOCAL_PATH="/home/syahrezank/${REMOTE_NAME}"

# Per-remote lock file -- THIS is the key fix.
# Without ${REMOTE_NAME} in the filename, two different
# remotes would share one lock and wrongly block each other.
LOCK_FILE="/tmp/rclone-bisync-${REMOTE_NAME}.lock"

MAX_RETRIES=3

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────
notify() {
  local urgency="$1"
  local title="$2"
  local body="$3"
  if [ "$NOTIFY" = true ]; then
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    notify-send --urgency="$urgency" --icon=dialog-information "$title" "$body"
  fi
}

# Prefix every log line with the remote name too --
# essential once you have two of these running, so you
# can tell Gdrive-1's log lines apart from Gdrive-2's
# in a shared journal/terminal.
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [${REMOTE_NAME}] $1"
}

# ─────────────────────────────────────────
# PREVENT CONCURRENT RUNS *OF THIS SAME REMOTE*
# (flock -- crash-safe, auto-releases on kill/crash)
# ─────────────────────────────────────────
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  log "Bisync already running for ${REMOTE_NAME}, skipping."
  exit 0
fi
# Note: this does NOT block Gdrive-1 vs Gdrive-2 from running
# together -- it only stops e.g. two Gdrive-1 runs overlapping.

# ─────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────
run_bisync() {
  log "Starting bisync."
  notify "low" "Rclone: Sync Started" "Syncing ${REMOTE_NAME}..."

  OUTPUT=$(rclone bisync "${REMOTE_NAME}:" "$LOCAL_PATH" \
    --create-empty-src-dirs \
    --compare size,modtime \
    --resilient \
    --recover \
    --conflict-resolve newer \
    --check-access \
    --fast-list \
    --transfers 4 \
    --drive-skip-shortcuts \
    --drive-export-formats desktop \
    --max-lock 30m \
    --verbose --progress 2>&1)

  if echo "$OUTPUT" | grep -qi "conflict"; then
    notify "normal" "Rclone: Conflict Detected" \
      "Run this to see conflicted files:\njournalctl -u rclone-bisync-${REMOTE_NAME}.service --since today | grep -i conflict"
  fi

  echo "$OUTPUT"
}

run_check() {
  rclone check "${REMOTE_NAME}:" "$LOCAL_PATH" \
    --size-only \
    --fast-list \
    --transfers 4 \
    --drive-skip-shortcuts \
    --drive-export-formats desktop \
    --quiet 2>/dev/null
}

# ─────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────
retry=0
while [ $retry -lt $MAX_RETRIES ]; do
  run_bisync

  if ! run_check; then
    retry=$((retry + 1))
    log "Changes detected after bisync, rerunning (attempt $retry/$MAX_RETRIES)."
    notify "low" "Rclone: Resyncing" "Changes found after sync, retrying (attempt $retry/$MAX_RETRIES)."
    continue
  fi

  log "Bisync complete and verified clean."
  notify "low" "Rclone: Sync Complete" "${REMOTE_NAME} is up to date."
  exit 0
done

log "Max retries ($MAX_RETRIES) reached, exiting. Will sync on next trigger."
notify "normal" "Rclone: Sync Incomplete" \
  "Max retries reached for ${REMOTE_NAME}. Some changes may be pending.\nWill retry on next trigger."
exit 0