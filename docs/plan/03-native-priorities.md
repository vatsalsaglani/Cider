# Native implementation priorities

Authorized by the user after the Phase 00 prototype. Implement in this order:

1. **Notch:** built-in display selection, passive hover expansion, configurable edge, pinning, explicit task capture, workspace recovery through the menu bar. Verify capture focus, Escape, display reconnection, Spaces and external-monitor focus on hardware.
2. **TODO:** shared capture, persistent completion/editing, local-date navigation, calendar. Follow with task deletion/undo, ordering and recoverable drafts. Native controls use the common tokens and accessible icon actions.
3. **Notes and workspace folders:** multiple selected folders, one lazy Vditor editor, borderless writing, frontmatter preservation, offline Mermaid/code highlighting, coordinated saves, conflict recovery and transactional image paste. The document contract remains the acceptance gate; a textarea is not a substitute.
4. **Usage and agent configurations:** Cider's connection and usage settings for Codex, Claude Code and Cursor. The user explicitly selected this scope. Provider enablement, account selection, refresh interval, connection status, quota windows, reset times and freshness belong here. Editing providers' models, permissions, MCP servers or hooks is outside this first version.

## Implementation checkpoints

The first runnable checkpoint is the notch and task foundation. It does not complete all four priorities. Keep the app useful at each checkpoint; do not show fabricated usage or nonfunctional navigation entries for unfinished features.

Connections must use a verified provider contract and explicit setup. Do not inspect credentials as part of development. Unsupported or unavailable usage remains unknown. A potential CodexBar adapter must be versioned and fixture-tested before live integration.

## Current deviation

The task/preferences checkpoint uses a versioned atomic JSON snapshot on a dedicated serial I/O queue, rather than the planned GRDB database. This limits the first checkpoint to small task collections. Migrate transactionally before adding the broader event/search model; preserve existing snapshots and test migration failure. This is not a performance or production-readiness claim.
