# rclone: Reza's Google Drive sync system

This repo is the **memory** for one long-running project: keeping Reza's Google Drive accounts in two-way sync with his Linux laptop using `rclone bisync`. Read it at the start of every session instead of relying on chat history. Earlier conversations got long enough that details were lost or contradicted.

## Who you're working with

- **Reza** (Syahreza, GitHub `syahrezank`). Timezone Asia/Jakarta (UTC+7).
- Laptop: Acer Aspire E5-475G, **Linux Mint** (Cinnamon, file manager Nemo, text editor xed). He also games on it, so background sync must stay light.
- Works across **many devices and OSes** on the same Drive accounts, so remote changes from elsewhere matter.
- Writes in English (sometimes mixed with Indonesian). Reply in the language he uses. Treat him as a peer and call him Reza.
- Call pull requests **"PulReq"**, never "PR". To him "PR" means homework.

## How he wants answers (standing preferences)

- **Research before answering.** For any rclone flag, behaviour or version question, check the official docs (`rclone.org`) or `rclone help flags` first. Do this even for things that feel familiar.
- Give detailed answers, but answer the actual question first.
- **End every reply with an honest hallucination level (0–100%)** and a short reason when it isn't low.
- If you're unsure, say so and explain why. Never be a confident, convincing liar.
- **Never invent rclone flags.** On 2026-03-17 an earlier session made up `--drive-skip-duplicates`, and it failed with `unknown flag`. Verify every flag you suggest. If you can't verify it, label it unverified.

## Memory protocol

**At session start:** read in this order: `STATE.md` (what is live now), `ISSUES.md` (open problems), then the newest file in `sessions/`. Check `DECISIONS.md` before suggesting anything that sounds like a reversal (e.g. "go back to mount", "add a pre-check", "add a dirty flag"). Each of those was already tried and dropped for a recorded reason.

**Source of truth for code:** `config/` holds copies captured from the laptop, each with a capture date in `config/README.md`. Before editing advice, check the date. If the laptop may have changed since then, re-capture it. The device bridge has `~/.script` granted from 2026-11-26. Otherwise ask Reza to paste the file. Never assume your own earlier drafts are what's running.

**At the end of any session that changed something or reached a conclusion:**
1. Update `STATE.md` if the live setup changed.
2. Add a dated entry to `DECISIONS.md` for every decision: the choice, why, and what was rejected.
3. Update `ISSUES.md`: add new problems, close fixed ones with the date.
4. Write `sessions/YYYY-MM-DD.md` (append `-2`, `-3` for more than one session per day): what was asked, what was found, what changed, and what's next.
5. Refresh `config/` copies if scripts changed.
6. Commit on a branch and open a PulReq. End your reply with **Your next steps**: which PulReq to merge, in what order, and what happens if it's left open. Also mention any other PulReqs still open.

Keep entries short and factual. Write the conclusion, not the whole chat.

## Safety rules (this repo is PUBLIC)

- **Never commit** `rclone.conf`, OAuth client IDs or secrets, tokens, `.lck`/`.lst` state files, or journal dumps.
- Don't record Drive file or folder names or contents beyond what's needed to explain a problem. Describe them generically instead ("a ~716-file folder rename"). Reza keeps personal notes and an encrypted vault in Drive.
- Bisync can delete data on both sides. Before advising any command that deletes, resyncs or changes paths, state the risk plainly and suggest `--dry-run` first. See `docs/runbook.md` → *Dangerous operations*.

## Repo map

| Path | What it holds |
|---|---|
| `STATE.md` | Current live setup: remotes, paths, triggers, flags, units |
| `DECISIONS.md` | Dated decision log with reasons and rejected alternatives |
| `ISSUES.md` | Open problems and improvement ideas, with priority |
| `docs/runbook.md` | Everyday commands: journalctl, manual sync, adding a remote, recovery |
| `docs/troubleshooting.md` | Known errors and symptoms → cause → fix |
| `docs/history.md` | Condensed timeline Dec 2025 → now (mount era → bisync) |
| `config/` | Captured copies of live scripts and units (see `config/README.md`) |
| `sessions/` | One note per working session |
