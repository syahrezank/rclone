# Current state

_Last verified: 2026-11-26. Scripts were captured from the laptop that day. Systemd units and the trigger helper have **not** been captured yet (see ISSUES #1)._

## Approach

Two-way sync with `rclone bisync` into ordinary local folders. **No FUSE mount.** The old `rclone mount` services were stopped and disabled on 2026-03-17. Why: [DECISIONS.md](DECISIONS.md) (2026-03-17).

## Remotes

| rclone remote | Local folder | Notes |
|---|---|---|
| `Gdrive` | `/home/syahrezank/Gdrive` | Personal Drive. ~14.4k objects listed. Has Google-side duplicate files (ISSUES #6). |
| `Gdrive-Work` | `/home/syahrezank/Gdrive-Work` | Added 2026-10-04. Same script, parameterised by remote name. |

- Both remotes use Reza's **own OAuth client** (set up Dec 2025).
- Convention: the local folder name equals the remote name (`LOCAL_PATH=/home/syahrezank/${REMOTE_NAME}`).
- Each side has an `RCLONE_TEST` marker for `--check-access`.
- Bisync state lives in `~/.cache/rclone/bisync/<Remote>_..home_syahrezank_<Remote>.{path1,path2}.lst`, plus a `.lck` while a run is active.

## Components

| Component | Where | What it does |
|---|---|---|
| `rclone-bisync-Gdrive.sh <remote>` | `~/.script/` ([copy](config/scripts/rclone-bisync-Gdrive.sh)) | Takes a `flock` per remote, then loops up to 3 times: bisync, then a `rclone check --size-only` post-check; reruns if anything differs |
| `rclone-watch-Gdrive.sh <remote>` | `~/.script/` ([copy](config/scripts/rclone-watch-Gdrive.sh)) | `inotifywait -m -r` on the local folder with a 60 s cooldown; on a change calls `sudo /usr/local/bin/rclone-trigger-bisync <remote>` |
| `rclone-trigger-bisync` | `/usr/local/bin/` (not captured) | Runs `systemctl start rclone-bisync-Gdrive@<remote>.service` via sudo. **Blocks** until the oneshot run finishes (ISSUES #2) |
| `rclone-bisync-Gdrive@.service` | `/etc/systemd/system/` (not captured) | Templated oneshot, instance = remote name. Runs the bisync script |
| Watcher service(s) | `/etc/systemd/system/` (not captured) | One watcher per remote (both were running on 2026-11-26) |
| Timer | `/etc/systemd/system/` (not captured) | Last known design: `OnBootSec=45s`, `OnUnitActiveSec=1h` |
| Resume service | `/etc/systemd/system/` (not captured) | Last known design: sleep 45 s after resume, then `systemctl start` the bisync service |

## Bisync flags in use (from the live script)

```
rclone bisync "${REMOTE}:" "/home/syahrezank/${REMOTE}" \
  --create-empty-src-dirs --compare size,modtime --resilient --recover \
  --conflict-resolve newer --check-access --fast-list --transfers 4 \
  --drive-skip-shortcuts --drive-export-formats desktop \
  --max-lock 30m --verbose --progress
```

Post-check: `rclone check --size-only --fast-list --transfers 4 --drive-skip-shortcuts --drive-export-formats desktop --quiet`.

Script settings: `NOTIFY=false` (desktop notifications off), `MAX_RETRIES=3`, watcher `COOLDOWN=60`.

## Triggers (what makes a sync run)

1. **Local change**: watcher → trigger helper → service.
2. **Hourly timer**, plus once 45 s after boot.
3. **Resume from suspend**, after a 45 s delay.
4. **Manual**: `./rclone-bisync-Gdrive.sh <remote>` or `sudo systemctl start rclone-bisync-Gdrive@<remote>.service`.

Remote-only changes (made on another device) are picked up only by triggers 2–4, or the next time a local change happens.

## Leftovers from the mount era (harmless)

- `/media/syahrezank/Gdrive` mountpoint directory, plus `user_allow_other` enabled in `/etc/fuse.conf`.
- `~/.script/unused/`: old script versions, plus `Sync-Gdrive.desktop` and `rclone-manual-Gdrive.sh` (a Nemo right-click "sync now" helper written for the old non-templated unit name).
