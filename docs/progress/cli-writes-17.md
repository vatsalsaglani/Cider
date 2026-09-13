# CLI task and note writes

The user authorized adding writes to the existing CLI. Direct CLI SQLite access remains read-only; a running Cider instance serves structured requests through a private per-store inbox and its shared repository/note services. No provider settings, hooks or installed skills are changed by these commands.

## Delivered behavior

- Task create/update, explicit complete/reopen, journal notes and task-note links. Updates require the current task revision and preserve unspecified fields.
- Folder/note discovery and explicit saved-note reads. Note create defaults to `~/Documents/Cider`, or an explicitly selected registered folder. Whole-file replacement and exact append require the current SHA-256 and use coordinated atomic replacement.
- Unsaved/recovered editor drafts block writes. An edit made during an in-flight file operation keeps its draft. Successful changes refresh shared app and graph models, with replacement file identity registered through the existing coordinator.
- Private directory 0700 and wire files 0600; one inbox owner via flock; bounded schema-versioned commands with instance lease and expiry; serial app execution. Permissions are prepared under an unpublished temporary name before rename so immediate consumption cannot turn a successful write into a CLI error.
- Stable JSON/exit codes, help, file/stdin UTF-8 input limits and a recovery path if file writing succeeded but connection registration failed. Timeout outcomes are uncertain; callers inspect saved state before retrying. No durable exactly-once guarantee or offline writes.
- Portable/generated workflow skill instructions now describe user-requested writes and revision/hash checks. Existing installations retain their prior content until reviewed setup is run again.

See [commands and recovery](../cli.md).

## Changed areas

`CLIWriteCommand` defines the closed vocabulary. `CLIWriteTransport` and `CLIWriteServer` own delivery; `CLIAppWriter` applies commands through the app. CLI argument parsing, output and help expose the commands. NotesModel protects drafts, LinkedNoteService provides hash-checked replacement, and CiderApp owns the server lifecycle. Test fixture defaults and note roots are isolated from user preferences/data.

## Verification

- 149 Swift tests in 27 suites passed, including task/hash conflicts, dirty-editor protection, replacement identity, graph links, missing-store behavior, inbox ownership/restart and 40 concurrent requests with immediate app consumption.
- 16 editor checks and linked-work synthetic checks passed.
- Final normal native build/relaunch and strict deep signature validation passed. Both bundled read-only and native write CLI smoke checks passed after the publication fix. An isolated staged package also ran with its original build directory unavailable before that fix.
- Packaged CLI checks exercise task create/update/complete/reopen/journal, note create/show/append/replace, links, default-folder isolation, malformed dates, option-like title values, UTF-8/size limits, traversal and stale revisions/hashes against a separate native fixture app.
- The initial packaged check exposed a publication race: chmod followed publication, but the server could remove the request first. Permission setup now precedes atomic publication, with concurrent-delivery coverage added.

No CUA or user task/note mutations were used. Physical UI acceptance and live provider integration are separate from these synthetic write checks.
