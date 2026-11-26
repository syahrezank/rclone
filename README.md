# rclone

Reza's Google Drive ↔ Linux laptop two-way sync (`rclone bisync`), plus the memory Claude uses to keep working on it across sessions.

- **What's running now:** [STATE.md](STATE.md)
- **Why it's built this way:** [DECISIONS.md](DECISIONS.md)
- **What's still broken or planned:** [ISSUES.md](ISSUES.md)
- **Commands and fixes:** [docs/runbook.md](docs/runbook.md), [docs/troubleshooting.md](docs/troubleshooting.md)
- **How it got here:** [docs/history.md](docs/history.md)
- **Live scripts (captured copies):** [config/](config/)
- **Session notes:** [sessions/](sessions/)

## Using it with Claude

Start a session on this repo and describe the problem. Claude reads `CLAUDE.md` and the files above first. At the end it records what changed and opens a PulReq for you to merge.

> ⚠️ This repo is **public**. Never commit `rclone.conf`, tokens or OAuth secrets. Consider making it private (Settings → General → Danger Zone → Change visibility).
