# Captured configuration

Copies of what actually runs on the laptop. **Edit the real files on the laptop, then re-capture them here.** Don't treat these copies as the place to make changes.

| File | Live location | Captured | How |
|---|---|---|---|
| [scripts/rclone-bisync-Gdrive.sh](scripts/rclone-bisync-Gdrive.sh) | `~/.script/rclone-bisync-Gdrive.sh` (mtime 2026-10-04) | 2026-11-26 | Device bridge, byte-for-byte |
| [scripts/rclone-watch-Gdrive.sh](scripts/rclone-watch-Gdrive.sh) | `~/.script/rclone-watch-Gdrive.sh` (mtime 2026-10-04) | 2026-11-26 | Device bridge, byte-for-byte |
| [systemd/](systemd/) | `/etc/systemd/system/rclone-*`, `/usr/local/bin/rclone-trigger-bisync` | **Not yet** | ISSUES #1 |

Never put `rclone.conf` here. It contains OAuth tokens, and this repo is public.
