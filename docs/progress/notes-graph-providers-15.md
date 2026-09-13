# Default notes, graph and additional providers

## Delivered behavior

- New Note with no workspace folders creates and remembers `~/Documents/Cider`, then opens an empty Markdown note. Existing folder/selected-note destinations retain precedence. Folder creation and note writes run on the I/O queue; conflicting paths and save failures retain recoverable writing.
- Graph shows unlinked saved work by default, uses a finite spring layout driven by saved relationships, and supports pan, zoom, fit/reset, drag-to-arrange, neighbor highlighting, an optional connection inspector, and double-click/open navigation. Its toolbar, count footer and background follow the existing ember workspace.
- Workspace indexing reads links in notes that have never been opened. Markdown links and unambiguous `[[Note name]]`, path, heading and alias forms produce saved graph edges without rewriting source. Matching stays inside each registered root. Fences, inline code and wiki embeds are excluded. Reads retain the existing 64 KiB limit and 2,000-file scan bound; unavailable/replaced/oversized files keep their saved relationships. This does not implement full Obsidian vault/editor compatibility.
- Cursor joins the existing reviewable activity Connect/Disconnect flow. Documented hooks normalize conversation/generation/child IDs and lifecycle events into the shared ledger, task journal, graph and notch notices. `afterAgentResponse` supplies a bounded response preview; only a matching completion event creates a completion peek. No tool arguments, prompts, transcript files or account email enter the observer spool. Child and old-turn completions cannot stop the current parent turn.
- Usage now has an independent provider catalog: Codex, Claude Code, Cursor & Grok Bot, and Grok Build. New connections default off and are enabled in Usage → Connection settings. Enabled providers appear in the notch. Existing cadence, Used/Remaining, source timestamps and last-good values are shared.

## Screenshot follow-up

The user's live screenshots exposed two issues missed by the first fixture set. The empty graph adopted its content height and became vertically centered in the workspace; the view now fills the workspace, anchors its header at the top, and gives the empty state a full-height canvas. The folder picker hides its redundant label, the one-option scope control is omitted, and Completed/Unlinked use ember-tinted buttons.

Creating/opening a note could race with workspace discovery: both allocated different IDs for the same file before either read the other's registration. A regression using eight simultaneous registrations reproduced `.conflict`. Both scanning and opening now share a pending registration keyed by canonical path, preserve the saved ID, and refresh graph revisions after opening/saving. All 139 tests pass after this fix; the normal native bundle was rebuilt/relaunched. The earlier isolated packaging checks precede this follow-up; live visual acceptance of the revised graph remains pending.

## CodexBar capability boundary

The existing bundled CodexBar CLI **v0.56.6** already supports the requested Bot quota. No new dependency or CUA integration was added.

| Connection | Implemented source | Limits |
| --- | --- | --- |
| Cursor local activity | [Cursor hooks](https://cursor.com/docs/hooks), including response and stop hooks | New session after reviewed setup; local observation. Cloud Bot lifecycle and human verification are not inferred. |
| Cursor & Grok Bot usage | Bundled CodexBar `--provider cursor --source auto` | Uses CodexBar's Cursor app/browser session resolution. Reports Cursor plan/model windows and optional `cursor-grok-bot` window under the same account. No Enterprise gate is imposed by Cider. A plan must actually report a Bot allowance; absent data stays unknown. |
| Grok Build usage | Bundled CodexBar `--provider grok --source oauth` with CLI fallback | Distinct from Grok Bot. Account/source limitations remain those of CodexBar; no universal quota availability claim. |
| Grok Bot live activity/response peeks | Not implemented | CodexBar's quota data does not establish a supported all-plan lifecycle feed. Bot links can be retained in tasks/notes. |

Pinned evidence: [Cursor provider docs](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/cursor.md), [Bot window mapping](https://github.com/steipete/CodexBar/blob/v0.56.6/Sources/CodexBarCore/Providers/Cursor/CursorSandUsage.swift), [Grok Build docs](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/grok.md), [quota models](https://github.com/steipete/CodexBar/blob/v0.56.6/Sources/CodexBarCore/UsageFetcher.swift). The Cursor Bot endpoint is a dashboard integration used by CodexBar, not a claimed stable public activity API.

The decoder preserves named window IDs, percentages and resets; treats `usageKnown: false` and synthetic windows as unknown; retains meaningful plan/model labels instead of replacing them with durations; and displays only matching-provider identity. No Cider-owned credential reader, browser scraping code or account-plan restriction was added. Cursor's opt-in connection describes its app/browser sign-in use before enabling it. Codex, Claude and Grok Build retain explicit OAuth/CLI-only fallback.

## Persistence and recovery

Internal database schema 2 adds Cursor to the chat provider constraint. The writer takes an owner-only SQLite backup at `<database>.v1-backup`, then transactionally rebuilds the constrained table and metadata while preserving host IDs, revisions, task links, assignment episodes and journal. Foreign keys are checked before committing and restored on failure. WAL-source backups are converted to a self-contained rollback journal so they can reopen read-only without new sidecars. Existing recovery copies are not overwritten. Read-only clients accept schema 1 and 2; the CLI envelope remains version 1.

## Verification

- `swift build --product Cider`: passed.
- `swift test`: **139 tests in 24 suites passed**, including concurrent note registration, default-folder creation/reuse, selected-root/error handling, indexing unopened notes, wiki resolution, layout bounds, Cursor normalization/setup preservation, new usage decoding/opt-in/source routing, and migration preservation/rollback/readable backups. The 1,000-node layout fixture completed in about 0.65 seconds in this debug test run; this is not a live idle-CPU measurement.
- `script/verify_editor.sh`: all 16 checks passed.
- `script/verify_linked_work.sh --fixtures`: passed after updating the smoke fixture's two-provider assumption to cover every tracked provider.
- `python3 script/verification/verify_cider_cli.py --binary .build/debug/cider-cli`: passed.
- Isolated SwiftPM build/package: passed. The original scratch directory was moved aside; the staged CLI verifier and strict signature check passed. Launching the staged native app created schema 2 and its fixture folder from packaged resources. An initial check incorrectly expected in-memory fixture chats to be persisted before task attachment; the corrected check verifies the actual persistence contract. The staged instance was stopped.
- `script/build_and_run.sh --verify` and `codesign --verify --deep --strict dist/Cider.app`: passed; the normal app was rebuilt and relaunched.
- `git diff --check`: passed.
- Built `cider-events cursor` with synthetic stdin and a temporary spool: normalized response observed, excluded account email absent; no user hooks/settings changed.

Live Cursor hooks, new provider sign-ins/quotas, Bot plan coverage, graph interaction/accessibility and physical-notch acceptance remain unverified. The user requested no CUA; final verification uses native builds, source inspection, command-line checks and synthetic fixtures.
