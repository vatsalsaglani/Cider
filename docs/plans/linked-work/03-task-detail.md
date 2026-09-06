# Plan 03 — TODO detail and chat attachments

Branch: `linked-work/03-task-detail`. Depends on: 01.
Runs in parallel with: 02, 04.

## Goal

Build the TODO detail surface with description, criteria, explicit status and multiple distinguishable chat contributors. Keep quick capture simple. The feature compiles against 01's model/fakes and can be wired by 05 without changing existing app navigation in this lane.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Sources/CiderDomain/TaskItem.swift:7`: `public var completed: Bool`. There is no richer task detail yet.
- `Features/Today/TodayView.swift:45`: `.sheet(item: $editing) { item in TaskEditView(model: model, original: item) }`. Row editing currently opens the small legacy form.
- `Features/Today/TaskRow.swift:16`: `Button(action: edit) {`. Preserve an explicit row detail action alongside a separate checkbox.
- `Sources/CiderUI/Components/CiderPillPicker.swift:4`: `public struct CiderPillPicker<Selection: Hashable>: View {`. Use the shared black/ember control rather than a blue system segmented control.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Features/LinkedTasks/TaskDetailView.swift`
- `Features/LinkedTasks/TaskOverviewView.swift`
- `Features/LinkedTasks/TaskChatPicker.swift`
- `Features/LinkedTasks/TaskLinksView.swift`
- `Features/LinkedTasks/TaskTimelineView.swift`
- `Sources/CiderUI/LinkedWork/TaskDraft.swift`
- `Tests/CiderLinkedWorkTests/LinkedTaskDraftTests.swift`
- `docs/plans/linked-work/03-task-detail.md`

Do not touch: `App/`, `Features/Today/`, `Features/Agents/AgentsView.swift`, `Features/Notes/`, `Features/Notch/`, `Package.swift` and all frozen files.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `docs/plan/05-linked-todos.md`: Product model, Entry points, Progress and completion.
- `docs/design/{design-system,components,tasks-and-capture,writing-and-sidebar}.md`: shared controls, surfaces and keyboard behavior.
- `contract-spec.md`: WorkTask, mutations, assignment start, shared model and entry points.
- `Sources/CiderUI/LinkedWork/` and `Sources/CiderDomain/LinkedWork/`: frozen API inputs.
- `Features/Today/{TodayView,TaskRow}.swift`, `Features/Agents/AgentsView.swift`: existing row and exact-title presentation, read-only.
- `Tests/CiderLinkedWorkTests/Support/`: protocol fakes for independent development.

## Precise edits

1. **TaskDetailView.** Implement `LinkedTaskDetailFeature` with Overview, Chats, Notes and Timeline using `CiderPillPicker`. Load by UUID; display loading/missing/conflict states and a compact path back to the board. Keep open drafts stable when incoming agent metadata refreshes.
2. **Overview/draft.** `TaskOverviewView` and `TaskDraft` edit title, description Markdown source, planned day, due date, criteria and the explicit five statuses. Track original revision, validate before save, and preserve a conflicting draft for reload/compare. Empty criteria do not produce an invented percentage. A checked task is human state, independent of a finished response.
3. **Chat picker.** `TaskChatPicker` searches observed chats by title/workspace/provider, showing source app, last-seen age and a short identity suffix for duplicate titles. Attach full `ChatIdentity`, optional role and scope. Default starts with upcoming observed turns; offer include-current only for an exact `currentTurnID`. Never link by workspace/title or implicitly resume/fork chats.
4. **Links.** `TaskLinksView` lists assigned chats and notes, with open/detach/view-connections routes. Detach retains checkpoints. Render saved note metadata now; use `chooseNotes(taskID:)` / `createLinkedNote(taskID:)` and the frozen route contract for the Notes feature implemented in 04. Do not reference unmerged concrete 04 types.
5. **Timeline baseline.** `TaskTimelineView` reads the journal interface and displays an empty state or user notes. Leave a real, bounded query-driven surface for 06's rich response history. No fabricated progress. The detail's explicit Delete action shows the task title and saved checkpoint count, and states that files/chats remain.
6. **Tests and integration handoff.** Add `LinkedTaskDraftTests` for row revisions, unrelated-field edits preserving status, checkbox semantics, and stale save preserving text. Provide synthetic SwiftUI previews using protocol fakes. Document the view init and callback requirements in this plan's handoff for 05.

## Constraints

Do not change AppModel, TodayView, global commands, observer hooks or the shared LinkedWorkModel. Do not start/send messages to any provider. Description text is user content; do not execute it or embed a second editor that writes the same note. No new graph implementation. Keep compact HUD geometry out of this feature; 05 owns it.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test --filter LinkedContractTests
swift test --filter LinkedTaskDraftTests
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- The four detail sections compile and work with synthetic repositories. Multiple same-title chats attach by distinct identity; criteria/status edits retain optimistic revisions; conflict handling preserves drafts. Notes/graph callbacks do not depend on sibling implementations.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Add linked TODO detail and contributor selection**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

None.

## Handoff

Plan 05 wires `TaskDetailView(taskID:model:navigate:)` at the existing task-detail
destination. Populate `LinkedWorkModel.availableChats` from observed Activity metadata
before showing the Chats section; the picker preserves the full `ChatIdentity` and never
matches a title or workspace. The `navigate` callback must resolve `.chat`, `.note`,
`.chooseNotes(taskID:)`, `.createLinkedNote(taskID:)`, and `.graph` through the frozen
route contract. Present the detail in a navigation or sheet context so its Back to board
action can dismiss. The feature owns only its transient draft; it reloads after successful
mutations and retains it after a conflict.

Review corrections: conflict handling now displays both the preserved local draft and the
newly read saved row. The user can explicitly adopt the saved row or rebase only local field
changes onto its newer revision; synthetic coverage verifies the subsequent rebased save.
Attached same-title contributors retain provider, source/workspace and an identity suffix.
Overview validation calls the frozen task validator and gives a field-level message without
discarding the draft. Evidence: `swift build --product Cider`, `LinkedContractTests`,
`LinkedTaskDraftTests`, and `git diff --check` were rerun after these corrections.

Follow-up review correction: the comparison now evaluates the latest still-editable draft,
with bounded values for every changed title, description, status, date, or criterion field.
Rebase uses that latest draft rather than the earlier conflict snapshot; synthetic coverage
types new text/status/criterion changes after conflict and verifies they persist on retry.

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/03-task-detail.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 03 on `linked-work/03-task-detail`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Build the TODO detail surface with description, criteria, explicit status and multiple distinguishable chat contributors. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test --filter LinkedContractTests; swift test --filter LinkedTaskDraftTests; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
