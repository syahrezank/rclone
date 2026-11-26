# Systemd units: not captured yet

The live units were rewritten on 2026-10-04 into a templated form (`rclone-bisync-Gdrive@<remote>.service`) and haven't been seen by Claude since. Capture them with the command in [ISSUES #1](../../ISSUES.md), then replace this file with the real units.

## Last known designs (from 2026-03-18, before templating; may be outdated)

**Bisync service.** Oneshot, never enabled directly:
```ini
[Unit]
Description=Rclone Bisync Google Drive
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=syahrezank
Group=syahrezank
ExecStart=/home/syahrezank/.script/rclone-bisync-Gdrive.sh   # now takes %i (remote name)
SuccessExitStatus=0 9
StandardOutput=journal
StandardError=journal
```

**Timer:**
```ini
[Timer]
OnBootSec=45s
OnUnitActiveSec=1h
Unit=rclone-bisync-Gdrive.service

[Install]
WantedBy=timers.target
```

**Resume.** Delegates to the bisync service:
```ini
[Unit]
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
User=root
ExecStartPre=/bin/sleep 45
ExecStart=/bin/systemctl start rclone-bisync-Gdrive.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
```

**Watcher.** Long-running:
```ini
[Service]
Type=simple
User=syahrezank
ExecStart=/home/syahrezank/.script/rclone-watch-Gdrive.sh   # now takes the remote name
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```
