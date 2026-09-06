# Plan 04 — Note references, backlinks and context files

Branch: `linked-work/04-note-links`. Depends on: 01.
Runs in parallel with: 02, 03.

## Goal

Make notes addressable by stable references, attach them to TODOs, and show backlinks without rewriting Markdown. Supply a reusable file service and note connection UI, including a reviewable checkpoint-to-note preview. App editor routing is deliberately reserved for 05 and 09.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Features/Notes/NotesModel.swift:12`: `var tabs: [URL] = []`. File URLs currently identify open tabs; durable graph links need their own stable note IDs.
- `Features/Notes/NotesModel.swift:75`: `guard await save() else { return }`. Opening linked notes must preserve this save-before-navigation boundary.
- `Features/Notes/NotesView.swift:21`: `MarkdownEditor(text: notes.body, document: file, changed: notes.changed, imagePasted: notes.pasteImage, openLink: notes.openLink, fragment: notes.fragment).id(notes.generation)`. The existing editor remains the single writer for an open document.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Sources/CiderData/LinkedNotes/LinkedNoteService.swift`
- `Sources/CiderData/LinkedNotes/NoteLocator.swift`
- `Sources/CiderData/LinkedNotes/MarkdownLinkIndex.swift`
- `Features/LinkedNotes/NoteConnectionsView.swift`
- `Features/LinkedNotes/NoteAttachmentPicker.swift`
- `Features/LinkedNotes/CheckpointNotePreview.swift`
- `Tests/CiderLinkedWorkTests/LinkedNoteTests.swift`
- `Tests/CiderLinkedWorkTests/MarkdownLinkIndexTests.swift`
- `docs/plans/linked-work/04-note-links.md`

Do not touch: `Features/Notes/NotesModel.swift`, `Features/Notes/NotesView.swift`, `App/`, `Features/LinkedTasks/`, `Package.swift`, schema and shared fixture files.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `docs/plan/05-linked-todos.md`: Notes/backlinks and graph edge semantics.
- `docs/contracts/documents.md`, `docs/design/writing-and-sidebar.md`: file coordination, unsupported Markdown and dirty navigation.
- `contract-spec.md`: note identity, file interface, roles, append proposal and route rules.
- `Sources/CiderDomain/LinkedWork/{Notes,NoteAccess,Repository,Commands}.swift`, `Sources/CiderUI/LinkedWork/`: frozen dependencies.
- `Features/Notes/NotesModel.swift`: open/create/save/link behavior, read-only.
- `Tests/CiderLinkedWorkTests/Support/FixtureNoteAccess.swift`: fixture contract.

## Precise edits

1. **File service.** Implement `LinkedNoteService` and `NoteLocator`: canonical root containment by path components; reject escaping symlinks, traversal and wrong roots. Resolve stable references using known file identity when possible. Missing/ambiguous files return a recoverable result, never a matching basename. Bound reads by bytes, UTF-8 boundary and declared truncation.
2. **Creation/append.** Create a uniquely named Markdown file in the explicit selected root/directory, using exclusive creation. `previewAppend` captures the file hash and exact proposed addition; `applyAppend` revalidates root/path/hash under file coordination and refuses external changes. It does not infer that an editor draft is saved. The scene coordinator must save first, generate the preview afterward, then reload after a confirmed append.
3. **Markdown link index.** `MarkdownLinkIndex` extracts actual relative Markdown links, including reference-style links, fragments and percent-encoded paths. Ignore code fences, inline code, images, remote schemes and unresolved paths. Resolve only known notes within selected roots. Preserve multiple fragments as distinct links and deterministic edge IDs. No wiki-link grammar or whole-disk crawler.
4. **Connections UI.** `NoteConnectionsView` implements `LinkedNoteConnectionsFeature`, lists linked TODOs/roles and routes open/link/unlink/view-connections. `NoteAttachmentPicker` supports search and explicit root selection, missing-root feedback, attach existing and create linked note. Use the repository for IDs/backlinks and the service for file IO.
5. **Checkpoint preview.** `CheckpointNotePreview` is a reusable value-driven sheet: source/chat/time, preview-only labeling, exact Markdown to add and explicit destination. It emits a confirmed selection/proposal callback; it must not bypass the app's dirty editor save. If creation succeeds but DB linking fails, keep the new file and offer registration retry.
6. **Tests.** `LinkedNoteTests` uses temporary roots for symlink escapes, sibling prefix collisions, rename identity, external edits, existing filename collisions and Unicode byte limits. `MarkdownLinkIndexTests` covers links in prose versus code/images, relative parent links inside root, reference syntax, URL escaping and unavailable targets. Assert Markdown remains byte-identical after attach/index operations.

## Constraints

No NotesModel/editor modifications, automatic frontmatter, remote asset fetches, basename relinking or user root crawling. No second note editor. Native security-scoped/bookmark handling must follow the document contract if required by the existing chosen-folder access; expose an unavailable root instead of broadening access. Do not change frozen interfaces to solve a file-service edge case.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test --filter LinkedContractTests
swift test --filter LinkedNoteTests
swift test --filter MarkdownLinkIndexTests
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- File service and note UI compile independently of 02/03 concrete features. Backlinks use stable IDs, reads/writes stay inside selected roots, conflict tests pass and linking/indexing leave source Markdown unchanged. The append preview has an explicit coordinator callback.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Add stable note links backlinks and safe note context access**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

Resolved by coordinator after merge: add optional `fileIdentity: Data? = nil` to frozen `NoteFileSnapshot` and its initializer. `LinkedNoteService` can then return the replacement's newly observed opaque filesystem identity through the existing `applyAppend` result. Plan 05 must copy that value into the same-ID `NoteReference` and use the already-frozen `.registerNote(note:)` upsert to persist it; no new `WorkChange` case is necessary. Plan 02 implements that upsert. Without this result field, a fresh service after relaunch must reject the old identity rather than accepting an arbitrary replacement at the same path.

Bookmark review evidence: a macOS `.minimalBookmark` created before `FileManager.replaceItemAt` resolves the replacement path with `bookmarkDataIsStale == true`; an unrelated external replacement at that same path has the same outcome. `URLResourceKey.fileResourceIdentifierKey` also changes. Therefore neither opaque bookmark nor resource-identifier data alone can distinguish a coordinated replacement from an unrelated replacement after restart while preserving the frozen result shape.

Review correction evidence: synthetic tests cover injected pre-replacement failure (original Markdown bytes remain intact), same-service stable-ID reads after atomic replacement, later external identity replacement rejection, malformed UTF-8 rejection, and oversized-file refusal before content is returned. The parser tests cover matching fence delimiters, double-backtick inline code, percent-encoded `#` filenames, image references, and ambiguous normalized targets.

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/04-note-links.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 04 on `linked-work/04-note-links`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Make notes addressable by stable references, attach them to TODOs, and show backlinks without rewriting Markdown. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test --filter LinkedContractTests; swift test --filter LinkedNoteTests; swift test --filter MarkdownLinkIndexTests; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).

Coordinator verification: optional fileIdentity result implemented; synthetic refreshed-reference restart test passed. Native build and all 81 tests passed. App persistence wiring remains the explicit Plan 05 gate.
