# Agent tracking and Cider naming

Implemented 2026-09-06. Native modules, executable, app bundle, source paths, scripts, editor scheme, and documentation now use Cider. The existing bundle identifier and task-storage directory intentionally retain their legacy spelling to preserve preferences and tasks. The previous generated app bundle was moved to `dist/previous-build` so only Cider.app remains launchable there.

## Delivered

- Bundled `cider-events` executable. Projects an allowlist of session/turn/child identifiers, workspace path, event/tool name and notification type. No prompt, reply, tool argument or transcript persistence. Silent success on invalid input and failures; one-second deadline, 1 MiB input/8 KiB event/2048 pending-file limits.
- Durable event spool and atomic ledger, UUID replay deduplication, old-turn terminal isolation, separate child identity, 30 events per session/256 sessions/24-hour retention. Quiet sessions retain last observed state with a five-minute freshness label. A response finishing never verifies user work.
- Shared native model with filesystem change notifications and dedicated I/O queue. HUD reads cached state. No provider calls on hover; version discovery runs once. Tracking and quota usage remain independent.
- Connect/Disconnect previews exact additive entries for Codex hooks.json and Claude settings.json. Stable bundled-helper copy in Application Support; preserves unrelated settings/hooks, idempotent installation, changed-file conflict detection, removal matches only Cider’s exact command. No actual user hooks were installed during development.
- Agents workspace: provider/project filters, recent-ended option, child groups, event timelines, age, app/Finder actions and session-ID copy. Fourth HUD tab, top-three parent sessions, attention badge. Explicit tab choice stays unchanged by events.

## Evidence

- Installed binaries report Codex CLI 0.153.4 and Claude Code 2.1.263. Hook/config shapes checked against [Codex hooks](https://learn.chatgpt.com/docs/hooks) and [Claude hooks](https://code.claude.com/docs/en/hooks). Local Claude Desktop Code uses shared hook configuration; Chat, Cowork and remote sessions are outside this adapter.
- `swift test`: 20 passed, including metadata exclusion, duplicate replay, old-turn stop, child isolation, stale semantics and setup preservation/idempotence/conflict/removal.
- `script/verify_editor.sh`: 16 WebKit checks passed after resource/scheme rename, including tables, links and Mermaid.
- Helper subprocess check: ten projected events, invalid JSON neutral, empty stdout/stderr, no sensitive fixture text persisted. Measured 4.9–537.1 ms including cold launch. Normal warm execution meets the intended 100 ms budget; cold launch does not yet.
- Native bundle build/launch passed. Final visual interaction blocked because the Mac is locked; no visual pass claimed.

## Deviations and remaining acceptance gates

Filesystem notifications replace the proposed Unix socket; the durable spool is the same boundary. Initial installation is user-level only; project-only setup is deferred. Provider version is displayed, but compatibility is not inferred solely from a version string. Receiving an event demonstrates delivery, not complete lifecycle coverage.

No process/crash inference, transcript discovery, automatic approval handling, optional notifications, or per-provider live attention-resolution reconciliation is claimed. A silent crashed process becomes stale rather than falsely completed. Labels deliberately say “Approval requested”; another hook may already have answered it. Without a provider turn ID, concurrent delivery cannot guarantee old-turn attribution. Source app actions do not claim to focus the originating CLI terminal or exact Desktop session.

Live hooks still require the user’s Connect action and Codex trust review. Verify two simultaneous sessions, subagents, approval/continuation/interrupt/exit and app-closed recovery across Codex CLI/Desktop and Claude CLI/local Desktop Code. Physical HUD tab switching/collapse remains a hardware gate. The app does not silently modify these external settings to satisfy a test.
