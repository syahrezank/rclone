# Decisions

Newest first. Each entry gives the decision, why it was made, and what was rejected. Check here before proposing something that reverses a decision.

---

### 2026-11-26: Use this repo as Claude's memory
- **Decision:** Keep state, decisions, issues, session notes and captured scripts in `syahrezank/rclone`.
- **Why:** The single chat had grown to the point where earlier details were lost or contradicted, e.g. advice to "add flock" when the live script already had it.
- **Structure:** Modelled loosely on `deep-space_kopdes` (CLAUDE.md + index + topic files + dated notes), simplified for a technical project.

### 2026-10-04: One parameterised script per role, templated systemd unit
- **Decision:** `rclone-bisync-Gdrive.sh <remote>` and `rclone-watch-Gdrive.sh <remote>` serve every remote. The unit is `rclone-bisync-Gdrive@<remote>.service`. Each remote gets its own lock and cooldown files.
- **Why:** Adding `Gdrive-Work` would otherwise mean duplicating every file. Separate locks let the two remotes sync concurrently.
- **Rejected:** Per-remote copies of each script. The old copies are in `~/.script/unused/`.

### 2026-10-04: `flock` instead of touch/rm lock files
- **Decision:** `exec 200>"$LOCK_FILE"; flock -n 200`. The watcher tests the lock with `flock -n "$LOCK_FILE" true`.
- **Why:** The kernel releases a flock when the process dies, so a crash or Ctrl+C can't leave a stale lock.
- **Added alongside:** `--max-lock 30m` to bisync, so rclone's own `.lck` expires if a run is killed. By default rclone locks never expire.

### 2026-03-18: Resume service delegates to the main bisync service
- **Decision:** The resume unit only does `sleep 45` then `systemctl start` the bisync service.
- **Why:** All sync logs end up under one unit, which makes debugging easier.

### 2026-03-18: Remove the dirty flag; keep the post-check loop
- **Decision:** After each bisync, run `rclone check --size-only`. If anything differs, bisync again, up to `MAX_RETRIES=3`.
- **Why:** The journal showed the dirty flag never caught anything that the post-check didn't. Fewer moving parts.
- **Accepted limit:** A change made *during* the final post-check, while the watcher is in cooldown, waits for the next trigger (at most 1 h via the timer). Bisync can't reach zero lag. Only a live mount can.

### 2026-03-18: No pre-check before bisync
- **Decision:** Always run bisync directly. No `rclone check` gate in front of it.
- **Rejected:** A two-tier "check, then bisync" design. It costs an extra full listing, and duplicates made the check disagree with bisync.

### 2026-03-18: Triggers are local change, 1 h timer, boot +45 s, resume +45 s
- **Rejected:** A 2- or 5-minute polling timer, because of worries about the Drive API quota and gaming performance. Also rejected: an "on folder open" inotify trigger (removed as unnecessary).
- **Watcher:** Uses `inotifywait -m` (continuous) with a timestamp cooldown rather than `sleep` inside the pipe, so it never goes blind.

### 2026-03-17: Compare `size,modtime` (no checksum)
- **Why:** Checksums are slow on the local side, and in practice size or modtime catches real edits. `--slow-hash-sync-only` was dropped with it.
- **Speed:** `--fast-list` added. Reza chose to keep `--transfers 4` and not raise transfers, checkers or chunk sizes.

### 2026-03-17: Shortcuts skipped, Google Docs exported as desktop links
- `--drive-skip-shortcuts` on both bisync and check, because shortcuts can pull in large targets and confuse listings.
- `--drive-export-formats desktop` keeps Google Docs/Sheets as small link files. Real two-way editing of Workspace files isn't possible. Edit those in the browser.

### 2026-03-17: Conflicts keep both copies (no `--conflict-loser delete`)
- **Decision:** Use `--conflict-resolve newer` with the default loser handling, which renames the loser to `.conflict1`.
- **Why:** With many devices, silently deleting the loser could throw away real work.
- **Notification:** Kept deliberately simple: "conflict happened, check journalctl". Currently `NOTIFY=false`.

### 2026-03-17: Local folder in `/home/syahrezank/<Remote>`, not `/media`
- **Why:** A plain folder under `/media` gets no sidebar entry without a mount, and it brings permission problems. Bookmark it in Nemo instead (Ctrl+D).
- **Rejected:** fstab, which is meant for block devices, and symlinking into the VFS cache, which corrupts the cache's state and syncs nothing back.

### 2026-03-17: Move from `rclone mount` to `rclone bisync`
- **Why:** The mount used `--dir-cache-time 9999h` and `--vfs-cache-max-age 9999h` for offline use, so **changes from other devices never showed up**. It also couldn't start offline at boot. Bisync gives real local files: usable offline, normal permissions, and multi-device safe.
- **Cost accepted:** Not real-time (changes arrive per trigger); full local copy on disk; bisync is officially beta.

### 2026-03-16: Logs go to journald, not dated log files
- **Why:** journald handles rotation and date filtering for free. The wrapper-script approach for dated log files was rejected as overkill.

### 2026-03-16 (mount era, now obsolete): `--vfs-file-perms 0644`
- Files on the FUSE mount reported `can-execute: TRUE`, so Nemo wouldn't open `.txt` files on double-click. Fixed with `--vfs-file-perms 0644 --vfs-dir-perms 0755`. Not relevant to bisync, where local files have normal permissions.
