# Linked work implementation and evidence

Date: 2026-09-07. Native macOS / Swift 6.3, arm64. Plans 01–09 integrate on the local `linked-work/09-integration` branch before merging to main.

## Delivered behavior

- SQLite-backed TODO descriptions, criteria and explicit states, with exact chat contributors and shared notes. Chats sharing a title or directory retain separate identities.
- Durable response previews and questions. Assignment episodes retain delayed responses after detach; matching question replies resolve the original chat/link. Ingestion commits before observer acknowledgement and retries safely after failed acknowledgement. Stop never implies Done or human verification.
- Native local/workspace graph, filters, bounded layout, list/inspector actions, and exact task/note/source routes. The graph is a view of saved relationships, not another database. The notch stays compact.
- Saved-context export from TODO Notes, with note bodies excluded by default and a separate explicit include-notes action. Read-only CLI commands expose the same saved repository, revisions, preview limits and truncation.
- Checkpoint destination selection within workspace roots, exact append preview, dirty-editor save checks, hash-checked atomic replacement and retryable metadata registration. An inert entry-ID marker avoids duplicate appends when the same checkpoint/destination is chosen after restart.
- Agent access setup in Agents, with project/CLI chooser, exact full-byte previews and explicit install/update/remove. Edited or unrelated skill files are preserved. No hooks or skills install automatically.
- Bundled `Contents/Helpers/cider`, portable `Contents/Resources/cider-workflow` and CiderData schema resources. The CLI build product remains `cider-cli` to avoid a case-insensitive collision with the app.

## Automated evidence

- `swift build --product Cider`: passed.
- `swift build --product cider-cli`: passed in normal and isolated package builds.
- `swift test`: 124 tests in 19 suites passed, including foundation, journal/recovery, graph/layout, context/setup and integrated workflow tests.
- `script/verify_editor.sh`: all 16 checks passed.
- `script/verify_linked_work.sh --fixtures`: smoke, foundation, whole-workflow and recovery tests passed.
- `python3 script/verification/verify_cider_cli.py --binary .build/debug/cider-cli`: passed using synthetic stores with no running-app dependency.
- Isolated package build at `/tmp/cider-plan09-isolated-build`, staged app at `/tmp/cider-plan09-staged/Cider.app`: passed. The original scratch build path was made unavailable by moving it to `/tmp/cider-plan09-retired-build`; staged CLI verification and strict signature validation passed. A staged app launch with a new fixture root created schema version 1 and metadata successfully, proving its schema lookup did not depend on the original build path. The packaged skill was present.
- `script/build_and_run.sh --verify`: normal app build/relaunch passed after correcting macOS Bash empty-array handling; `codesign --verify --deep --strict dist/Cider.app` passed. The final normal app is running outside fixture mode.
- `git diff --check`: passed.
- No tests read credentials or use real note/transcript contents. No live prompts were sent and no provider configuration was changed.

## Limits and manual review

UI acceptance is deferred by the user's explicit instruction. Native keyboard/accessibility, Reduce Motion interactions, settled/hidden CPU measurement, physical notch/multi-display behavior and live provider skill invocation are unperformed acceptance checks, not passes. Ad-hoc signature validation is not notarization or distribution approval.

Responses are bounded observer previews, currently up to 600 characters, not full transcripts. Historical question resolution scans at most 4,096 entries per task; exceeding the bound fails conservatively and retains the spool. An indexed origin query remains a future scalability improvement. Replaying the same source event is deduplicated; separate hook invocations with new IDs remain at-least-once.

Context is capped at 256 KiB and linked note access at 64 KiB. Today's CLI summary contains at most 20 task contexts. The graph caps at 1,000 nodes/3,000 edges; local depth is one or two. Missing/exited sources retain recovery guidance. Terminal pane targeting, full-output collection, agent write CLI, automatic completion, remote sync and Obsidian vault/wiki-link compatibility are outside this delivery.

## Migration and rollback

The app's task store is `~/Library/Application Support/Cider/work.sqlite`. First import reads the legacy `~/Library/Application Support/Cinder/workspace.json`, preserves task UUIDs and leaves its bytes intact, with a `.cider-backup` copy. Migration failure keeps the workspace unavailable rather than overwriting it with an empty board.

Before manual rollback, quit Cider and preserve `work.sqlite` together with any `-wal`/`-shm` files as one backup set. Keep the legacy JSON and its backup. Reverting the binary to a pre-linked-work version displays the old JSON snapshot; it does not contain subsequent SQLite changes. Restore a matching complete backup with the app stopped rather than replacing an open database. Never delete Markdown files to roll back TODO metadata. Project skill removal is an explicit reviewed action in Agent access and refuses user-edited managed files.
