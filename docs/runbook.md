# Runbook

All unit names below use the **templated** form `rclone-bisync-Gdrive@<remote>.service`, where `<remote>` is `Gdrive` or `Gdrive-Work`. Watcher and timer unit names aren't captured yet (ISSUES #1), so check with `systemctl list-units 'rclone*'`.

## Is it healthy right now?

```bash
systemctl list-units 'rclone*' --all          # which units exist and their state
systemctl list-timers | grep rclone           # last and next timer run
ps -eo pid,etime,cmd | grep -E "rclone bisync|rclone-watch|rclone-trigger" | grep -v grep
ls -la ~/.cache/rclone/bisync/*.lck 2>/dev/null   # a .lck exists only while a run is active (or after a crash)
```

## Logs

```bash
journalctl -u 'rclone-bisync-Gdrive@*' -f                      # live, both remotes
journalctl -u 'rclone-bisync-Gdrive@Gdrive.service' --since today --no-pager
journalctl -u 'rclone-bisync-Gdrive@Gdrive.service' -p err --since today
journalctl -u 'rclone-bisync-Gdrive@*' --since today | grep -i conflict

# Useful lines only (removes --progress noise and duplicate notices)
journalctl -u 'rclone-bisync-Gdrive@Gdrive.service' --since "-1h" --no-pager \
  | grep -vE "Transferred:|Checks:|Elapsed time:|Deleted: +[0-9]|Duplicate object" \
  | grep -E "\[Gdrive\]|changes:|Copied|Deleted|ERROR|NOTICE: Failed|conflict|successful"
```

While a run is in progress the bisync journal stays **empty**. Output is printed only when the run finishes (ISSUES #3). Silence doesn't mean it's stuck.

## "Already running, skipping": is it really running?

1. `ps -eo pid,etime,cmd | grep "rclone bisync" | grep -v grep`. If you see a process, a run is active.
2. Is it making progress? Run `grep -E 'rchar|wchar' /proc/<pid>/io` twice, about 15 s apart. Growing numbers mean it's working.
3. If there's no process but a `.lck` exists, rclone crashed. The lock expires by itself after `--max-lock 30m`, or delete it: `rm ~/.cache/rclone/bisync/<Remote>_..home_syahrezank_<Remote>.lck`.
4. If a process has been running for hours and its I/O doesn't change, it's hung. Run `sudo systemctl stop 'rclone-bisync-Gdrive@<remote>.service'` (a graceful SIGTERM; `--recover` handles the next run).

The script's own lock is a `flock` and can't go stale. **Never use `--resync` to fix a lock problem.**

## Manual sync

```bash
~/.script/rclone-bisync-Gdrive.sh Gdrive            # in a terminal, prints when done
sudo systemctl start 'rclone-bisync-Gdrive@Gdrive.service'   # via systemd, logs to journal (blocks until done)
```

## Add a new remote (as done for Gdrive-Work)

1. `rclone config`: create remote `<Name>` with your own OAuth client.
2. `mkdir -p ~/<Name>`. The local folder name must equal the remote name.
3. `touch ~/<Name>/RCLONE_TEST && rclone touch <Name>:RCLONE_TEST`
4. Run a dry-run resync. Read the output before going further.
   ```bash
   rclone bisync <Name>: /home/syahrezank/<Name> --resync --dry-run \
     --create-empty-src-dirs --compare size,modtime --resilient --recover \
     --conflict-resolve newer --check-access --fast-list --transfers 4 \
     --drive-skip-shortcuts --drive-export-formats desktop --verbose
   ```
5. Run the same command without `--dry-run`. Never put `--resync` in the script.
6. Enable the watcher and bisync instances for `<Name>` (unit names: ISSUES #1).

Shell gotcha (2026-10-04): don't end a line with `2>&1` and then continue with `--resync`, and don't leave a stray `)` behind. `2>&1` only belongs in the script's `$(...)` capture.

## Dangerous operations

| Operation | What happens | Safe way |
|---|---|---|
| Deleting the local folder contents, then a normal bisync | Bisync treats it as you deleting everything, and **deletes it on Drive too** (above 50% `--max-delete` it aborts instead) | Run `--resync` (see below), which merges and restores from Drive |
| `--resync` | Ignores the saved state and merges both sides. Nothing is deleted, but files you deleted on one side come back | `--dry-run` first |
| Renaming a big local folder | Re-uploads everything and deletes the old copies on Drive (ISSUES #4) | Rename on the Drive web UI, or test `--track-renames` |
| Changing compare or filter flags | Old listings no longer match the new rules | Run `--resync` once (as done when adding `--drive-skip-shortcuts`) |

## Start completely fresh (one remote)

```bash
sudo systemctl stop 'rclone-bisync-Gdrive@<Remote>.service'     # and stop its watcher
rm ~/.cache/rclone/bisync/<Remote>_*            # bisync state only
# Optional: re-download everything:  rm -rf ~/<Remote>/*  (then: touch ~/<Remote>/RCLONE_TEST)
# Then run steps 4–5 of "Add a new remote"
```
