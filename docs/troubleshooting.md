# Troubleshooting: symptom → cause → fix

Real cases from this project. Add a row whenever a new one is solved.

## Bisync era (current)

| Symptom / message | Cause | Fix |
|---|---|---|
| `Bisync already running for <remote>, skipping` repeatedly | A real run is still active (a long transfer, or the retry loop starting another pass). The flock can't go stale | Check `ps` and `/proc/<pid>/io` ([runbook](runbook.md#already-running-skipping-is-it-really-running)). 2026-11-26: a folder rename took ~15 min |
| A run takes 10+ min with `Path2: N changes: X new, 0 modified, X deleted` (equal counts) | A local folder rename. Bisync re-uploads everything under the new name, then deletes the old copies. Drive allows ~3 writes/s per account | Let it finish. Next time, rename on both sides before syncing (ISSUES #4) |
| Journal is missing lines (a pass with no end, a run with no `Starting bisync.`) | Huge output burst (from `--progress`) tripped journald's rate limit, which drops lines | `journalctl … \| grep -i suppressed` to confirm. Fix in ISSUES #3 |
| Post-check fails right after a big run and a second pass uploads lots of "new" files | Something created files locally during the run (2026-11-26: a restored folder). The retry loop is working as intended | Nothing to do. Check `Path2: N changes` to see what it was |
| Small syncs every few minutes with `.obsidian/*.json` "time (newer)" | Notes app open on a vault inside the synced folder | See ISSUES #9 |
| Journal shows `Starting bisync.` and then nothing for minutes | Output is captured into `$OUTPUT` and printed only at the end | Normal for now. ISSUES #3 fixes it |
| `cannot find prior Path1 or Path2 listings` | No `--resync` has ever been done for this remote/path pair (or the state was deleted) | Run a `--dry-run --resync`, then a real `--resync` once |
| `Fatal error: unknown flag: --drive-skip-duplicates` | **The flag doesn't exist.** An earlier Claude session invented it | Remove it. Verify flags with `rclone help flags \| grep <word>` |
| `Duplicate object found in source - ignoring` | Google Drive allows two files with the same name in one folder | Harmless; one copy isn't synced. Fix with `rclone dedupe` (ISSUES #6) |
| Shortcuts still synced although expected skipped | `--drive-skip-shortcuts` was missing from the resync or the check | Add it to bisync **and** check, then `--resync` once so the state matches |
| `bash: syntax error near unexpected token ')'` and `--resync` ignored | A line ended with `2>&1` and then continued; a stray `)` was left over | Remove the `2>&1` and `)` from manual commands |
| Post-check always "finds changes" | Check and bisync use different flag sets (e.g. shortcuts or duplicates handled differently) | Keep the check flags aligned with bisync (the same `--drive-*` flags) |
| `systemctl restart rclone-bisync-Gdrive-resume.service` takes ages | It has `ExecStartPre=sleep 45` | Don't restart it. `daemon-reload` is enough for oneshot units |
| `Unit rclone-bisync-Gdrive.service could not be found` | The unit is templated now | Use `rclone-bisync-Gdrive@Gdrive.service` |
| `The unit files have no installation config` on disable | The oneshot service has no `[Install]` section by design (started by the timer, watcher or resume) | Harmless |

## Mount era (historical, 2026-03-16)

| Symptom | Cause | Fix |
|---|---|---|
| `mkdir /media/...: Permission denied` | `/media` is owned by root | `sudo mkdir -p` + `sudo chown syahrezank:` |
| `fusermount3: user has no write access to mountpoint` | The mountpoint was still owned by root | `chown` + `chmod 755` |
| `option allow_other only allowed if 'user_allow_other' is set in /etc/fuse.conf` | FUSE security default | Uncomment `user_allow_other` in `/etc/fuse.conf` |
| `.txt` won't open on double-click in Nemo (right-click → Open With works) | Mount reported files as executable (`access::can-execute: TRUE`) | `--vfs-file-perms 0644 --vfs-dir-perms 0755` |
| Changes from other devices never appear | `--dir-cache-time 9999h` and `--vfs-cache-max-age 9999h` | Design limit. The reason for moving to bisync |
