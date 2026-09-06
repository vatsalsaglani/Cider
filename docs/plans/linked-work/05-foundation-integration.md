# Plan 05 — Connect TODOs, notes, chats and the notch

Branch: `linked-work/05-foundation-integration`. Depends on: 02, 03, 04.
Runs in parallel with: none; coordinator runs locally.

## Goal

Integrate round A locally into a working TODO/chat/note workflow and migrate app task writes to the new store. Existing calendar, quick capture, Notes tabs and notch behavior must continue to work. This clean, verified commit becomes the common base for journal, graph and CLI lanes.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `App/WorkspaceView.swift:11`: `@State private var notes = NotesModel()`. Notes navigation is currently owned inside the workspace view; linked routes need a scene coordinator with access to that same instance.
- `App/WorkspaceView.swift:40`: `else if selection == "Agents" { AgentsView(model: agents) }`. Agent Activity has no TODO-link route yet.
- `App/AppModel.swift:49`: `private func commit(_ change: (inout AppSnapshot) -> Void) async -> Bool`. This writer must be replaced, not kept alongside a second database writer.
- `Features/Notch/NotchHUDView.swift:91`: `Button { Task { await model.toggle(task) } } label: {`. Preserve the direct completion checkbox while adding an independent detail navigation action.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `App/AppModel.swift`
- `App/CiderApp.swift`
- `App/WorkspaceView.swift`
- `App/NoteCommands.swift`
- `Features/Today/TodayView.swift`
- `Features/Today/TaskRow.swift`
- `Features/Notes/NotesModel.swift`
- `Features/Notes/NotesView.swift`
- `Features/Notes/NoteTabStrip.swift`
- `Features/Notes/WorkspaceTree.swift`
- `Features/Agents/AgentsView.swift`
- `Features/Agents/AgentTrackingModel.swift`
- `Features/Notch/NotchHUDView.swift`
- `App/LinkedWorkCoordinator.swift`
- `Tests/CiderIntegrationTests/LinkedFoundationTests.swift`
- `script/verification/LinkedWorkSmoke.swift`
- `script/verify_linked_work.sh`
- `docs/plans/linked-work/05-foundation-integration.md`

Do not touch: Frozen domain/schema/package files and earlier implementation files not in this ownership list. Small integration fixes outside it require the coordinator to amend ownership and record the reason before editing.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- Plans 02–04 and their Deviations/handoffs; inspect each committed diff before merging.
- `contract-spec.md`, actual frozen Domain/UI declarations and the merged store/note/detail implementations.
- `App/{AppModel,CiderApp,WorkspaceView,NoteCommands}.swift` and `Features/Today/{TodayView,TaskRow}.swift`.
- `Features/Notes/{NotesModel,NotesView,NoteTabStrip,WorkspaceTree}.swift`: one editor/save lifecycle.
- `Features/Agents/{AgentsView,AgentTrackingModel}.swift`, `Features/Notch/NotchHUDView.swift`: exact-source open, attention and compact geometry.
- `docs/design/{tasks-and-capture,notch-behavior,writing-and-sidebar}.md`, `docs/verification.md`: regression gates.

## Precise edits

1. **Composition.** Add `App/LinkedWorkCoordinator.swift` to own repository readiness, LinkedWorkModel and routes in the existing scene lifecycle. Instantiate one authoritative store and note service; expose both to the relevant views. Register the existing folder preference through explicit import. Keep app launch errors visible and do not silently start an empty replacement workspace.
2. **Task cutover.** Change AppModel load/create/toggle/update/notch preference writes to repository transactions. Retain `snapshot` only as a compatibility view populated from authoritative reads; account for pagination so tasks beyond the first 100 are not lost. Use expected row revisions on edits, one refresh after successful writes and refresh on activation/revision changes. The legacy JSON is not a second writer. Preserve day drafts and completion ordering.
3. **Entry points.** Replace row editing with TaskDetailView. Wire attach-existing/create-from-chat actions in Agent Activity; actions identify full provider/session/host and populate a reviewable draft. Add Notes tab/tree connection actions and a NoteConnectionsView inspector. Show chat-related notes through their TODO, without claiming direct agent file use. Missing chats can show saved provenance but never fall back to another session.
4. **File/navigation lifecycle.** Route notes through the same NotesModel save-before-open path. Register canonical note references on open/create and reconcile explicit rename/root removal. Save before checkpoint append, build the proposal after save, apply only the reviewed proposal and reload the editor. A failed save leaves the current document/draft untouched. Avoid two editors or stale cached content overwriting an external change.
5. **Compact notch.** Add linked-chat count/attention to TODO rows using bounded shared components. Checkbox toggles completion; row click opens TODO detail; a separate contributor action returns to the exact chat. Keep all counters inside safe geometry, preserve tabs/peeks/hover collapse and avoid expanding a full inspector in the HUD.
6. **Round B seam.** Project current tracked sessions into ChatReference, including exact titles/origins/turn IDs, and refresh metadata only for existing registered chats. Route `createTaskFromChat`/`createTaskFromNote` to editable drafts and `chooseNotes`/`createLinkedNote` to the note picker, with no sibling view reaching into NotesModel. Keep a composition point for WorkJournalIngesting; the actual durable ingestion path lands in 06. Graph/context-export routes remain hidden or clearly unavailable until 09 wires them; never ship a broken navigation path. The checkpoint-to-note callback can be exercised with a synthetic journal entry now.
7. **Verification harness.** Add `LinkedFoundationTests` and a synthetic fixture-only smoke entry point in `script/verification/LinkedWorkSmoke.swift`. `script/verify_linked_work.sh --fixtures` builds/runs it against a temporary store and temporary notes, never live Application Support. Cover migration, detail saves, many-to-many links, dirty navigation, relaunch and failed-save recovery. Commit evidence and unresolved hardware gates in the coordinator's overview log.

## Constraints

This phase begins only after 02–04 merge and their checks pass. It owns existing central app files intentionally; no parallel lane runs during the cutover. Do not relaunch an older app against a stale pre-migration backup. A live migration is a coordinator-only step with verified recoverable task data; all automated tests use fixtures. Future CLI is read-only, so no IPC server is required.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test
script/verify_editor.sh
script/verify_linked_work.sh --fixtures
git diff --check
```

After fixture gates pass, coordinator only: run `script/build_and_run.sh --verify` for native packaging/relaunch and inspect the fixture workspace flow with CUA. This script stops the globally running Cider and may fetch bundled helper dependencies; never run it in parallel. Use the fixture harness to validate mutations, not existing user notes. Separately record any physical notch/dirty-editor behavior not exercised; a successful build alone is insufficient.

## Definition of done

- All round A features are reachable from the actual scene; DB is the only task writer; existing IDs/days/settings and note drafts survive. Full tests/editor checks and fixture smoke pass. The coordinator records a new exact common base before 06–08 start.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Connect linked TODOs notes and agent activity across Cider**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/05-foundation-integration.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 05 on `linked-work/05-foundation-integration`. Run locally as the coordinator; do not create a lane worktree for this plan. Goal: Integrate round A locally into a working TODO/chat/note workflow and migrate app task writes to the new store. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test; script/verify_editor.sh; script/verify_linked_work.sh --fixtures; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).

## Coordinator amendment from Plan 04 review

NoteFileSnapshot now includes optional fileIdentity. After confirmed applyAppend, copy that returned identity and modifiedAt into the same-ID NoteReference and persist through registerNote before success is reported. Keep the receipt for retry if registration fails; do not repeat the append. Test repository reopen and a fresh note service reading the refreshed reference, plus a failed registration retry without duplicate Markdown. See contract-spec.md.
