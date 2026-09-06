# Plan 06 — Durable response and question history

Branch: `linked-work/06-journal`. Depends on: 05.
Runs in parallel with: 07, 08.

## Goal

Persist attributed response and question previews in a TODO timeline before the observer can prune or acknowledge them. Preserve history across restarts and detachments, without claiming that a Stop proves completion. This lane leaves CLI, graph and global app composition to sibling/integration plans.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Sources/CiderDomain/AgentTracking.swift:45`: `lastMessage = ["Stop", "SubagentStop"].contains(event) ? field("last_assistant_message", limit: 600, keepLines: true) : nil`. Available output is a preview, not the full response.
- `Sources/CiderDomain/AgentTracking.swift:113`: `row.history.append(event); row.history = Array(row.history.suffix(30))`. Visible agent history cannot be the durable TODO journal.
- `Sources/CiderData/AgentEventStore.swift:22`: `ledger.sessions = ledger.sessions.filter { Date.now.timeIntervalSince($0.value.updated) < 86400 }`.
- `Sources/CiderData/AgentEventStore.swift:25`: `for (file, _) in events { try? fm.removeItem(at: file) }`. Journal capture must occur before this acknowledgement.
- `Features/Agents/AgentTrackingModel.swift:74`: `if !stopped.isEmpty { onUsageStop?(stopped) }`. Preserve provider usage refresh and existing peek behavior when changing ingestion.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Sources/CiderData/AgentEventStore.swift`
- `Features/Agents/AgentTrackingModel.swift`
- `Sources/CiderData/LinkedWork/JournalIngestor.swift`
- `Sources/CiderData/LinkedWork/JournalAttribution.swift`
- `Features/LinkedTasks/TaskTimelineView.swift`
- `Tests/CiderLinkedWorkTests/LinkedJournalTests.swift`
- `Tests/CiderLinkedWorkTests/LinkedJournalRecoveryTests.swift`
- `docs/plans/linked-work/06-journal.md`

Do not touch: `App/`, `Features/Graph/`, `Sources/CiderCLI/`, `Sources/CiderEventHelper/`, frozen domain/schema, store transaction implementations and user hooks.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `contract-spec.md`: Durable journal and attribution; read all eight rules and the batch/revision API.
- `Sources/CiderDomain/{AgentTracking,AgentQuestion,AgentNotice}.swift`: event/turn/question reducers and freshness rules.
- `Sources/CiderData/AgentEventStore.swift`, `Features/Agents/AgentTrackingModel.swift`: ingestion, acknowledgement and notification callbacks.
- `Sources/CiderData/LinkedWork/` and `Sources/CiderDomain/LinkedWork/`: merged transactional repository, frozen declarations.
- `Features/LinkedTasks/TaskTimelineView.swift`: round A query-driven baseline.
- `Tests/CiderDomainTests/AgentTrackingTests.swift`: existing synthetic observer regression cases.

## Precise edits

1. **Staged ingestion.** Refactor AgentEventStore internally into read batch and commit/acknowledge operations. AgentTrackingModel awaits `WorkJournalIngesting` between them. A failed journal write keeps spool files unacknowledged, reports recoverable failure and retries with bounded backoff. Keep work off MainActor. Add a single ingestion guard so overlapping refreshes cannot consume the same batch concurrently.
2. **Attribution.** `JournalAttribution` uses immutable host/provider/session identity, assignment intervals and proven turn/request IDs. Default attachments begin at the next observed prompt; exact current-turn inclusion is opt-in. Match delayed Stops to their original episode, never a new assignment by directory. Missing/ambiguous IDs stay qualified or unassigned. Child results require proven parent relation. Concurrent attachment changes cause repository revision conflict and recomputation.
3. **JournalIngestor.** Build source-preserving drafts for Stop/SubagentStop previews, questions and question resolutions. Keep 600-character preview labeling. Commit episodes, processed IDs and entries atomically. Replays must not duplicate checkpoint sequences; without stable provider keys, report the invocation-level dedupe limitation. Do not store answer bodies or scrape transcripts.
4. **Timeline.** Extend TaskTimelineView with grouped source/chat/time, native Markdown preview, question/resolution pairing, incremental paging and explicit `saveCheckpoint` route. Distinguish reported response from criteria and user verification. Keep stored entries after detach/cache expiry; never mark task Done on Stop. Refresh only when relevant revision changes.
5. **Notification preservation.** Existing fresh question/completion peeks, attention resolution and provider-specific usage Stop callback still run for fresh events. Recovery after app downtime persists old checkpoints without replaying a burst of peeks. A nil ingestor is permitted only in an explicitly isolated test/legacy setup; 09 must wire the production instance before calling this feature complete.
6. **Tests.** Add `LinkedJournalTests` and `LinkedJournalRecoveryTests` with synthetic batches covering two chats in one cwd, two tasks sharing a contributor, link during a turn, unlink/reassign, delayed old Stop, duplicate UUID/turn IDs, absent IDs, question answer resolution and parent/child ambiguity. Inject failures before DB commit, after commit/before ledger save, and before spool removal. Restart must retain journal data without duplicate entries or false notifications.

## Constraints

Do not modify the helper, hook settings, provider event schema or full-output capture. Keep current 8 KiB envelopes, one-second helper and bounded spool reads. No data loss to satisfy cache limits; journal retention is independent. Do not log bodies. Durable journal failures must be visible rather than silently discarding source events. App startup wiring belongs to 09.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test --filter AgentTrackingTests
swift test --filter LinkedJournalTests
swift test --filter LinkedJournalRecoveryTests
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- Failure-injection tests prove capture-before-acknowledgement, replay safety and correct assignment scope. Timeline shows durable preview history and questions without altering completion. Existing peeks and usage callbacks retain their freshness semantics.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Persist attributed agent checkpoints before observer acknowledgement**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/06-journal.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 06 on `linked-work/06-journal`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Persist attributed response and question previews in a TODO timeline before the observer can prune or acknowledge them. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test --filter AgentTrackingTests; swift test --filter LinkedJournalTests; swift test --filter LinkedJournalRecoveryTests; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
