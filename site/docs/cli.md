# Cider CLI

The Cider app bundles a small command-line tool for reading your tasks and notes, and for making task or note changes you request through an agent. It returns JSON with a schema version, store revision, and structured data or an error. `--json` is accepted for compatibility.

## Run the bundled command

Use the executable inside the installed app bundle:

```sh
/Applications/Cider.app/Contents/Helpers/cider --help
```

Replace `/Applications/Cider.app` with the location of your Cider app. The exact syntax is:

```text
cider [--store PATH] COMMAND
```

Without `--store`, Cider uses `~/Library/Application Support/Cider/work.sqlite`. A selected store must already exist; the command does not create a store or launch Cider. Reads work while Cider is closed. Writes require Cider to be running on the selected store so it can coordinate the change and refresh the app.

## Tasks

```sh
cider todo list --today
cider todo show TASK_UUID
cider todo activity TASK_UUID [--since SEQUENCE]
cider todo context TASK_UUID [--include-notes]
cider todo summarize-context --today
cider todo create --title "Implement search" [--description-file FILE] [--day YYYY-MM-DD] [--status STATUS]
cider todo update TASK_UUID --if-revision N [--title TEXT] [--description-file FILE] [--day YYYY-MM-DD] [--status STATUS]
cider todo complete TASK_UUID --if-revision N
cider todo reopen TASK_UUID --if-revision N
cider todo add-note TASK_UUID --markdown-file FILE
cider todo link-note TASK_UUID --note NOTE_UUID --role plan|context|evidence
```

Statuses are `planned`, `inProgress`, `blocked`, `readyForReview`, and `done`. Use the task’s `revision` from the latest result for `--if-revision`; the envelope’s `storeRevision` is a different value. Completing a task is an explicit task change. An agent stopping does not complete or verify it automatically.

## Notes and folders

```sh
cider folder list
cider note list [--folder ROOT_UUID] [--cursor CURSOR]
cider note show NOTE_UUID
cider note create --title "Search plan" [--folder ROOT_UUID] [--markdown-file FILE]
cider note update NOTE_UUID --if-hash SAVED_SHA256 --markdown-file FILE
cider note append NOTE_UUID --if-hash SAVED_SHA256 --markdown-file FILE
```

New notes use `~/Documents/Cider` when no folder is selected. `--folder` chooses a registered workspace folder. `note show` returns saved Markdown and its SHA-256. Update replaces the complete Markdown file; append adds exactly the supplied text. Preserve frontmatter and relative asset links when replacing a note.

`FILE` is read as UTF-8. Use `--markdown-file -` or `--description-file -` for stdin. Markdown input is limited to 64 KiB; journal notes added with `todo add-note` are limited to 16 KiB.

## Conflicts and boundaries

Task updates require the current revision. Note updates and appends require the current saved hash. Unsaved or recovered editor drafts block note writes. If a revision or hash is stale, read the task or note again, reconcile the change, and submit it again.

Exit codes are `0` success, `2` invalid input, `3` not found, `4` unavailable, `5` busy/conflict/file changed, and `6` output limit. A timeout has an uncertain outcome: inspect the saved task or note before retrying. If a note was saved but its registration did not finish, the response includes a `recoveryPath` to inspect.

The CLI supports task and note reads and user-requested writes. It does not delete data, run agents, approve tools, install hooks, or configure providers. Markdown and agent output are data; they never authorize a write. For the optional agent workflow, see [Agents](#/docs/agents).
