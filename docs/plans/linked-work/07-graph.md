# Plan 07 — Local and workspace relationship graph

Branch: `linked-work/07-graph`. Depends on: 05.
Runs in parallel with: 06, 08.

## Goal

Build the interactive local and workspace graph of saved TODO, chat and note relationships. Users can explore connections and return to the exact entity. A keyboard-accessible connection list provides the same information as the canvas, using Cider's black/ember design.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `App/WorkspaceView.swift:40`: `else if selection == "Agents" { AgentsView(model: agents) }`. The current workspace has routed feature surfaces but no graph; global navigation belongs to 09.
- `Features/Notes/NotesModel.swift:69`: `func open(_ url: URL, anchor: String = "") async {`. Graph note actions must route through this existing editor lifecycle rather than opening a second viewer.
- The graph extension in `docs/plan/05-linked-todos.md` defines explicit edges; same workspace/title is not evidence of a relationship. Round A supplies the actual store/backlinks.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Features/Graph/WorkGraphView.swift`
- `Features/Graph/GraphCanvas.swift`
- `Features/Graph/GraphInspector.swift`
- `Features/Graph/GraphFilters.swift`
- `Sources/CiderUI/LinkedWork/GraphLayout.swift`
- `Sources/CiderUI/LinkedWork/GraphViewport.swift`
- `Tests/CiderLinkedWorkTests/LinkedGraphTests.swift`
- `Tests/CiderLinkedWorkTests/GraphLayoutTests.swift`
- `docs/plans/linked-work/07-graph.md`

Do not touch: `App/`, `Features/Agents/`, `Features/Notch/`, `Sources/CiderData/LinkedWork/WorkGraphQueries.swift`, `Package.swift`, frozen types and sibling CLI/journal files.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `docs/plan/05-linked-todos.md`: Graph view and relationship semantics.
- `docs/design/{design-system,components,writing-and-sidebar}.md`: palette, controls and accessibility.
- `contract-spec.md`: GraphQuery/GraphSnapshot bounds, relationships, identity and LinkedRoute.
- `Sources/CiderDomain/LinkedWork/Graph.swift`, `Sources/CiderUI/LinkedWork/` and merged `WorkGraphQueries.swift`: read-only contracts/query implementation.
- `Features/LinkedTasks/TaskLinksView.swift`, `Features/LinkedNotes/NoteConnectionsView.swift`: connection actions to match.
- `Tests/CiderLinkedWorkTests/Fixtures/linked-v1.json`: duplicate titles and shared note cases.

## Precise edits

1. **WorkGraphView.** Implement `LinkedGraphFeature`. Support focused depth-one/two graph and workspace selection, node type/provider/status/activity/search filters, isolated nodes and completed work controls. Use repository queries with explicit node/edge limits and visible truncation. No separate relationship store.
2. **Layout/viewport.** `GraphLayout` computes bounded deterministic initial positions off MainActor. Preserve stable node positions and GraphViewport pan/zoom/selection across incremental updates. Support drag/pin positions, fit selection and reset layout. A pin is layout state, never a saved relationship. Cancel stale queries/layout generations when switching focus. Stop layout/animation when settled or hidden; honor Reduce Motion.
3. **Canvas.** GraphCanvas draws distinct TODO/chat/note shapes/icons and explicit edge types with readable labels. Show execution/attention separately from TODO status. Unavailable notes and historical chats remain identifiable. Do not create a node for every Stop or invent direct chat-to-note edges through a TODO.
4. **Inspector/list.** GraphInspector exposes the exact title, workspace, status and connections with Open/View connections actions through LinkedRoute. A connection list supports keyboard focus, VoiceOver and searching without using the canvas. Context actions reuse the frozen repository mutations for explicit links/unlinks; a drag never attaches anything.
5. **Tests.** `LinkedGraphTests` compares graph edge identities with task/note backlinks after attach/detach/relaunch, checks duplicate-title nodes and filtered endpoint bounds. `GraphLayoutTests` verifies deterministic finite positions, viewport retention, cancellation and bounded work at the 1,000-node/3,000-edge ceiling. Include a settled/hidden state test proving no continuously scheduled layout task.
6. **Handoff.** Supply synthetic previews and note the exact WorkGraphView initializer and navigation callbacks for 09. Measure layout time with fixture size/machine details; do not claim native interaction, accessibility or idle CPU evidence from a unit test alone.

## Constraints

No WebKit graph/server or third-party force-layout dependency. The existing editor remains the only WebKit exception. No provider APIs, network fetching, vault import, wiki-link edits, embeddings, automatic similarity links or new graph DB. Do not change global App navigation or the store schema. Keep graph out of the notch; only compact View connections actions belong there.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test --filter LinkedGraphTests
swift test --filter GraphLayoutTests
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- Graph and connection list use identical saved edges; exact entity navigation callbacks are emitted; all limits/filter/layout tests pass. No continuous work remains when settled/hidden. Native interaction and accessibility checks are explicitly handed to 09.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Add native linked work graph and accessible connection explorer**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/07-graph.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 07 on `linked-work/07-graph`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Build the interactive local and workspace graph of saved TODO, chat and note relationships. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test --filter LinkedGraphTests; swift test --filter GraphLayoutTests; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
