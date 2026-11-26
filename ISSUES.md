# Open issues and ideas

Priority: **H** = causes wrong or missed syncs or data risk · **M** = makes debugging hard or wastes resources · **L** = nice to have.
Close an item by moving it to *Closed* with the date and the fix.

## Open

### #1 [M] Systemd units and trigger helper not captured in this repo
Only the two scripts are in `config/`. To capture the rest, run this once on the laptop:
```bash
{ systemctl list-unit-files 'rclone*'; echo; systemctl cat 'rclone-*' 2>&1; echo; \
  echo '===== /usr/local/bin/rclone-trigger-bisync'; cat /usr/local/bin/rclone-trigger-bisync; echo; \
  echo '===== sudoers'; sudo grep -rh rclone /etc/sudoers /etc/sudoers.d/ 2>/dev/null; \
  echo; rclone version; } > ~/.script/systemd-capture.txt 2>&1
```
Claude can then read `~/.script/systemd-capture.txt` through the device bridge.

### #2 [M] Watcher freezes for the whole length of a bisync run
`rclone-trigger-bisync` presumably calls `systemctl start` without `--no-block`. On a `Type=oneshot` unit that waits until the run ends. On 2026-11-26 the watcher sat inside `trigger_sync` for 15+ minutes. Events queue in the pipe and are handled afterwards, so nothing is lost, but a large burst then floods the journal with one "within cooldown" line per event.
**Fix:** Use `systemctl start --no-block` in the helper (needs #1 first). Possibly also throttle the per-event cooldown log line.

### #3 [H] Journal is blind during a run, and drops lines after big runs
The script captures rclone output with `OUTPUT=$(...)` and only prints it when the run ends, so `journalctl -f` shows nothing while it's running. `--progress` also floods the journal with redraw lines (tens of thousands of lines for one run on 2026-11-26). On 2026-11-26 that burst very likely tripped journald's default rate limit (10 000 lines / 30 s per unit), and **log lines were dropped**: the end of a pass, the retry message, the next pass's start. Errors could be lost the same way. To confirm: `journalctl --since <time> | grep -i suppressed`.
**Fix:** Stream output with `| tee "/tmp/rclone-bisync-${REMOTE_NAME}.out"`, grep that file for conflicts, drop `--progress`, and add `--stats 30s --stats-one-line`.

### #4 [H] Renaming a local folder re-uploads everything and deletes the originals on Drive
On 2026-11-26 a local rename of a ~716-file folder showed up as 716 new + 716 deleted. That run took ~15 min (≈116 MiB re-uploaded), and the post-check loop then started another full run. On Drive the old files are deleted and new ones uploaded, which likely means **new file IDs** (old share links break, and version history stays with the deleted copies). Unverified, but expected.
**Measured (2026-11-26):** Uploads ran at ~90 files/min (16:15:51–16:21:43). Deletes ran 16:21:44–16:22:35. The run didn't finish until ~16:30, and that 7½ min tail isn't explained yet (see Next in `sessions/2026-11-26.md`). Upload speed is in line with Google's documented "~3 sustained write requests/s per account, can't be increased", so raising `--transfers` won't help much.
**Workaround now (from the bisync docs):** Rename the folder **to the same name on both sides** (laptop + Drive web) before the next sync. Bisync then sees both sides agree, with no re-upload and no `--resync`. Pause the watcher while doing it, or it will sync the half-done state.
**Longer-term:** `--track-renames`, supported in bisync since v1.66. Per the docs it is not available during `--resync` and needs a common hash on both listings, so it is incompatible with `--ignore-listing-checksum`. Our `--compare size,modtime` currently sets that automatically. To do: check `rclone version`, work out the needed `--compare`/hash change and the local MD5 cost, and test with `--dry-run`.

### #5 [L] Conflict notification points at the wrong unit name
The script's notify text says `journalctl -u rclone-bisync-${REMOTE_NAME}.service`. The real unit is `rclone-bisync-Gdrive@${REMOTE_NAME}.service`. It's harmless while `NOTIFY=false`. The same old name is in `unused/rclone-manual-Gdrive.sh`.

### #6 [L] Duplicate files on the Google side
The `Gdrive` remote logs ~45 "Duplicate object found in source - ignoring" notices every run, all in one folder. One copy of each is never synced locally.
**Fix:** Review with `rclone dedupe --dedupe-mode list "Gdrive:<folder>"`, then dedupe (interactively or with `newest`). It's safe to run while bisync isn't running, and the next bisync just sees deletions on Path1.

### #7 [L] Retry loop re-lists everything each time
Each retry does a full listing of both sides (~14k objects, ~10 s for listings alone) plus a full post-check listing. That's fine normally, but it multiplies after big changes. Consider leaving it as is. Noted so it doesn't get "rediscovered" as a bug.

### #8 [L] Watcher's lock probe can race with the bisync script
`flock -n "$LOCK_FILE" true` takes the lock for an instant. If the bisync service starts at that exact moment, it logs "already running, skipping" for a run that wasn't running. It's very unlikely and self-healing on the next trigger.

### #9 [M] Notes-app vault open inside the synced folder
Since 2026-11-26 an Obsidian vault lives in `~/Gdrive` and is open in the app. The app rewrites its config and workspace files while you use it, so the watcher triggers frequent full bisync runs (~20 s each, listing ~14k objects). The vault also has its own sync plugin (Remotely Save). **Two sync systems on the same files can fight**: overwrites, conflicts, or ping-pong uploads. That depends on where the plugin syncs to, which is unknown.
**Options:** Pick one sync system for the vault. If bisync stays, consider excluding the app's volatile workspace files with a filter (this changes the filter set, so it needs a `--dry-run` + `--resync`; check the exact rclone filter rules and bisync's filter-change behaviour before doing it).

## Closed

- **2026-11-26: "Bisync stuck"** was a false alarm. The run was busy syncing a folder rename (#4). See `sessions/2026-11-26.md`.
- **2026-10-04: Lock files left behind by crashes.** Prevented by the switch to `flock` plus `--max-lock 30m`.
