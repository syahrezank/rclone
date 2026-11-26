#!/bin/bash

# ─────────────────────────────────────────
# USAGE:
#   ./rclone-watch.sh <remote-name>
#   e.g. ./rclone-watch.sh Gdrive-1
#        ./rclone-watch.sh Gdrive-2
#
# One watcher script, reused per remote. Each instance
# watches only its own folder and only ever triggers its
# own matching bisync service -- Gdrive-1 changes never
# wake up Gdrive-2's sync, and vice versa.
# ─────────────────────────────────────────

REMOTE_NAME="$1"   # must match the remote name used in the bisync script

if [ -z "$REMOTE_NAME" ]; then
  echo "Usage: $0 <remote-name>"
  exit 1
fi

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
NOTIFY=false

WATCH_DIR="/home/syahrezank/${REMOTE_NAME}"

# Must match the LOCK_FILE path in the bisync script EXACTLY,
# since this script tests the *same* flock, not a copy of it.
LOCK_FILE="/tmp/rclone-bisync-${REMOTE_NAME}.lock"

COOLDOWN=60

# Per-remote cooldown timestamp file -- if this were shared
# across remotes, a change in Gdrive-1 would reset the cooldown
# clock for Gdrive-2 too (and overwrite each other's timestamp
# whenever both watchers wrote to it at once).
LAST_LOCAL="/tmp/rclone-watch-local-last-${REMOTE_NAME}"

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

# Tag every log line with the remote name -- essential once
# two watchers are writing to the same journal/terminal.
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [${REMOTE_NAME}] $1"
}

# ─────────────────────────────────────────
# INIT
# ─────────────────────────────────────────
echo "0" > "$LAST_LOCAL"
log "Watcher started."
notify "low" "Rclone: Watcher Active" "Monitoring ${WATCH_DIR} for changes."

# ─────────────────────────────────────────
# TRIGGER
# ─────────────────────────────────────────
trigger_sync() {
  local reason="$1"

  # Test the ACTUAL flock, not file existence -- with the
  # exec-based lock, the lock file stays on disk permanently,
  # so checking "-f" would always be true after the first run
  # and this would never trigger again. "flock -n ... true"
  # grabs the lock and instantly releases it if nothing else
  # holds it; it fails (nonzero) if a real bisync is running.
  if ! flock -n "$LOCK_FILE" true 2>/dev/null; then
    log "$reason — bisync already running, skipping."
    return
  fi

  log "$reason — triggering sync."
  notify "low" "Rclone: Change Detected" "$reason"

  # Each remote gets its own systemd unit, matching the
  # per-remote bisync script from before.
  sudo /usr/local/bin/rclone-trigger-bisync "${REMOTE_NAME}"
}

# ─────────────────────────────────────────
# WATCHER
# ─────────────────────────────────────────
watch_local_changes() {
  inotifywait -m -r \
    -e modify -e create -e delete -e moved_from -e moved_to \
    --format '%e %w%f' \
    "$WATCH_DIR" 2>/dev/null |
  while read -r event filepath; do
    now=$(date +%s)
    last=$(cat "$LAST_LOCAL")
    if (( now - last >= COOLDOWN )); then
      echo "$now" > "$LAST_LOCAL"
      trigger_sync "Local change detected ($event: $filepath)"
    else
      # NEW: makes a debounced event visible instead of silent,
      # so this never again looks like a dead watcher.
      remaining=$(( COOLDOWN - (now - last) ))
      log "Change detected ($event: $filepath) — within cooldown, ${remaining}s left. Will be picked up by next sync."
    fi
  done
}

# ─────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────
cleanup() {
  log "Watcher stopping, cleaning up."
  notify "low" "Rclone: Watcher Stopped" "${WATCH_DIR} is no longer being monitored."
  rm -f "$LAST_LOCAL"
  kill $(jobs -p) 2>/dev/null
  wait 2>/dev/null
  exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

# ─────────────────────────────────────────
# RUN
# ─────────────────────────────────────────
watch_local_changes &

wait -n
log "Watcher exited unexpectedly."
notify "critical" "Rclone: Watcher Crashed" \
  "The ${REMOTE_NAME} watcher stopped unexpectedly. Systemd will attempt restart."
cleanup