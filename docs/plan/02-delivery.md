# Delivery after feasibility

These are planning work orders, not authorization to execute. At each phase start, resolve exact owned paths against the implemented scaffold and freeze contracts before fan-out.

## Phase 02 — local daily loop

Depends on P01-B/P01-D and the native shell. Lanes: Notes (folder tree, tabs, frontmatter, local assets), Today (task state/order/planned dates, calendar, shared quick/notch capture), Features (manual feature/phase/lane/run associations). UI lanes own their `Features/<name>/` paths and tests; coordinator owns shared repositories/contracts and shared IconAction/material primitives.

Acceptance: open three folders; create/edit/reopen notes and relative assets outside Cider; add/complete/reorder/reschedule tasks from day, toolbar and notch; browse/reset dates and switch calendar/list; preserve drafts across changes; map a multi-repository feature and two phases; recover an unsaved draft and an external-edit conflict. All local flows work with every provider disconnected. Icon actions have help/VoiceOver names and keyboard/menu equivalents. The app includes the ember backdrop and native material fallbacks. Jira is a URL link only.

## Phase 03 — reliable agent attention

Depends on P01-C and Phase 02 identity/storage. Lanes: Claude observation, Codex observation, Inbox/projection UX. Adapter paths stay separate; all events enter the same reducer. Coordinator owns notifications, cursor reconciliation, and shared state transitions.

Acceptance: watch independently launched sessions in several worktrees; surface explicit input/approval/failure states once; preserve unread/resolved history; open the correct source or show a truthful fallback; rehydrate after restart/disconnect; distinguish idle/completed/stale/unknown. Event loss and unsupported capabilities are visible. The live MVP gate cannot pass on only synthetic events or file-recency heuristics.

## Phase 04 — review and handoff

Depends on notes, Inbox, and run/revision linkage. Lanes: native screenshot annotation; verification/finding UX; plan import and dependency mapping. `Capture/` belongs to annotation, `Features/Review/` to verification, and `Features/PlanImport/` to importer; shared evidence schema remains coordinated.

Acceptance: record tests against a specific head, paste UI plus network/console evidence, annotate without altering originals, create a task from a finding, export/copy an ordinary Markdown feedback bundle, and retest a new revision. Import a fan-out of plans through a preview with ambiguous/missing dependencies shown. Unsupported send channels remain copy/open actions.

## Phase 05 — quotas and Jira

Usage and Jira can proceed independently after their setup decisions. Provider lanes own their own adapter paths and fixtures; Usage UI consumes the frozen quota shape. Jira owns its client/outbox/UI only after the authorization model is chosen.

Acceptance for usage: Codex, Claude Code and Cursor display verified account/window values, reset times, freshness, and unknown/auth/offline behavior. Refresh is bounded and no account quotas are averaged. The app remains useful if any provider is unavailable.

Acceptance for Jira: select a site/project; import chosen issues; map tasks explicitly; preview writes; handle workflow transitions, pagination, rate limits, offline outbox, duplicate-create reconciliation, and remote conflicts. A local checkbox never silently overwrites remote work. Verify against a designated test issue before enabling general mutations.

## Phase 06 — hardening and distribution

Run performance, accessibility, persistence stress, sleep/wake, multi-monitor and provider-version matrix. Use Instruments Time Profiler/Allocations/Leaks/Energy and SwiftUI tools as relevant; measure the WebKit process. Fix hot paths based on traces.

Prepare app icons from an approved design, signed/notarized direct-download packaging, launch-at-login preference through supported APIs, first-run permission explanations and uninstall/revoke-hook instructions. Automatic updates require an explicit distribution decision and signed-update strategy; do not bundle a framework by habit.

Acceptance: [verification checklist](../verification.md) passes, source/dependency notices are included, fresh install and upgrade recover data correctly, settings/bookmarks survive restart, support diagnostics redact content/secrets, and rollback instructions identify how to restore the pre-upgrade store without deleting notes.

## Deferred scope

Remote agent transport, built-in agent orchestration, agent-to-agent messaging control, autonomous verification commands, cloud sync/collaboration, semantic AI search, music/games/voice, and third-party plugin marketplaces are later product decisions. The MVP can link existing orchestration plans without becoming another orchestration engine.

## Release unit and rollback

Ship one phase behind explicit capability/feature flags when needed. A failed adapter can be disabled without touching notes/tasks. A failed rich-renderer upgrade can revert the pinned editor bundle while preserving source files. Database downgrade uses a pre-migration backup; never attempt a reverse migration without a proven path. Imported hook changes retain their exact removal diff.
