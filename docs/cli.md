# Cider CLI

The app bundles `Contents/Helpers/cider`. Run that executable with `--help` for all commands. Commands return JSON with a schema version, store revision and structured data or error; `--json` remains accepted for compatibility.

Reads work while Cider is closed. Writes require Cider running on the selected store so the app coordinates persistence and refreshes tasks, notes and connections. `--store PATH` selects a store; it does not create one or launch Cider.

## Agent plugins

Use **Agents → Agents → Install Cider plugin…** for Codex or Claude Code. The same option is available while connecting an agent. Installation is optional and account-wide; start a new agent session afterward. The plugin supplies a workflow skill using this CLI. See [setup and removal](../Integrations/agent-plugins/README.md).

## Tasks

```sh
cider todo create --title "Implement search" --day 2026-09-14
cider todo list --today
cider todo show TASK_UUID
cider todo update TASK_UUID --if-revision 1 --title "Implement note search"
cider todo complete TASK_UUID --if-revision 2
cider todo reopen TASK_UUID --if-revision 3
cider todo add-note TASK_UUID --markdown-file ./progress.md
cider todo link-note TASK_UUID --note NOTE_UUID --role plan
```

Use the task's `revision` from the latest result, not the envelope's `storeRevision`. Updates preserve unspecified fields. Create/update accept `--description-file FILE`, `--day YYYY-MM-DD` and `--status planned|inProgress|blocked|readyForReview|done`. Completion is an explicit user-requested task change; an agent response never completes or verifies work automatically. Journal notes accept up to 16 KiB. Link roles are `plan`, `context` and `evidence`.

## Notes

```sh
cider folder list
cider note list
cider note create --title "Search plan" --markdown-file ./plan.md
cider note show NOTE_UUID
cider note append NOTE_UUID --if-hash SAVED_SHA256 --markdown-file ./addition.md
cider note update NOTE_UUID --if-hash SAVED_SHA256 --markdown-file ./replacement.md
```

Creation uses `~/Documents/Cider`, creating and remembering the folder as needed. `--folder FOLDER_UUID` selects an available registered workspace folder. Titles are file names without paths; name collisions are handled by the existing note service. Note listing supports `--folder` and `--cursor`.

`note show` explicitly reads saved Markdown and returns its SHA-256. Replacement writes the entire supplied Markdown file; preserve frontmatter and relative asset links in the replacement. Append adds exactly the supplied text, so include desired newlines. File/stdin input is UTF-8, bounded to 64 KiB; `--markdown-file -` and `--description-file -` read stdin. Notes with unsaved or recovered editor drafts reject writes. A stale task revision or changed note hash rejects the edit; read again and reconcile before submitting it again.

## Recovery and boundaries

Exit codes: `0` success, `2` invalid input, `3` not found, `4` unavailable, `5` busy/conflict/file changed, `6` output limit. A timeout does not prove a write failed: inspect the task/note before retrying. If a note was saved but connection registration failed, the error includes `recoveryPath`; inspect that file before retrying creation. There is no durable exactly-once retry guarantee.

The CLI opens SQLite read-only. Writes use a private per-store inbox, a live app lease and a single app executor. Requests from an expired app instance are discarded on restart. It supports task/note writes only: no deletion, agent execution, permission approval, hook installation or provider configuration. Markdown and agent output are data, never instructions authorizing writes. Installed workflow skills are updated only through the existing reviewed setup flow.
