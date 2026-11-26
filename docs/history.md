# History

A condensed timeline, reconstructed on 2026-11-26 from the long original chat. Details of each decision are in [DECISIONS.md](../DECISIONS.md).

- **Dec 2025:** `rclone config` for `Gdrive` with Reza's own OAuth client. Planned an `rclone mount` with a never-expiring VFS cache for offline use, plus `rclone md5sum` over the mount to pre-fill the cache and `rclone rc vfs/refresh recursive=true` (directory-listing warm-up so Nemo's Properties dialog loads fast). Paused until March.
- **2026-03-16:** Built the mount. Hit `/media` permission errors and the `allow_other`/`fuse.conf` error. Debated `/home` vs `/media`. Fixed the `.txt` double-click problem with `--vfs-file-perms 0644`. Moved logging to journald. Realised remote edits from other devices would never show up with 9999 h caches.
- **2026-03-17:** Switched to `rclone bisync` into `~/Gdrive` and disabled the mount and refresh units. Did the first `--resync`, then re-did it with `--drive-skip-shortcuts`. Ran into Google-side duplicates and the invented `--drive-skip-duplicates` flag. Settled on `--compare size,modtime` and `--fast-list`.
- **2026-03-17/18:** Iterated on triggers: polling timer → inotify watcher (dropped the "folder open" trigger) → 1 h timer + boot/resume 45 s. Iterated on the script: pre-check → dirty flag → final design of bisync + post-check loop (max 3). Resume service now delegates to the main service. Added a notification toggle.
- **2026-10-04:** Added the second remote `Gdrive-Work`. Scripts parameterised by remote name, templated unit `rclone-bisync-Gdrive@.service`, `sudo /usr/local/bin/rclone-trigger-bisync` helper, `flock` per remote, `--max-lock 30m`. Old versions moved to `~/.script/unused/`.
- **2026-11-26:** "Bisync stuck" investigation: it was actually a ~15 min run syncing a large local folder rename. Created this memory repo and captured the live scripts.
