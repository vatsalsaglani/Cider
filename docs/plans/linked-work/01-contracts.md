# Plan 01 — Shared contracts and build seams

Branch: `linked-work/01-contracts`. Depends on: the committed plan set.
Runs in parallel with: none; coordinator runs locally.

## Goal

Create the compiled shared types, SQLite schema, protocol fakes and package seams that all later lanes will consume. This is a local coordinator phase. It does not migrate user data, install a skill or expose incomplete UI. After this phase, plans 02, 03 and 04 must build independently from one exact commit.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Sources/CiderDomain/TaskItem.swift:7`: `public var completed: Bool`. Today's task has no description, criteria or contributor identity. Keep it as a compatibility projection instead of adding a competing persisted status.
- `Package.swift:11`: `.target(name: "CiderData", dependencies: ["CiderDomain"])`. There is no shared database module or CLI target yet.
- `Sources/CiderData/SnapshotStore.swift:20`: `guard value.version == 1 else { throw CocoaError(.fileReadUnknown) }`. The legacy decoder is a real migration boundary, not a blank schema.
- Source baseline verification: `swift test` passed 53 tests in four suites before this plan set. New schema tests must supplement that baseline.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Package.swift`
- `Sources/CSQLite/module.modulemap`
- `Sources/CSQLite/shim.h`
- `Sources/CiderDomain/LinkedWork/Identity.swift`
- `Sources/CiderDomain/LinkedWork/Tasks.swift`
- `Sources/CiderDomain/LinkedWork/Notes.swift`
- `Sources/CiderDomain/LinkedWork/Links.swift`
- `Sources/CiderDomain/LinkedWork/Journal.swift`
- `Sources/CiderDomain/LinkedWork/Graph.swift`
- `Sources/CiderDomain/LinkedWork/Commands.swift`
- `Sources/CiderDomain/LinkedWork/Repository.swift`
- `Sources/CiderDomain/LinkedWork/NoteAccess.swift`
- `Sources/CiderData/LinkedWork/Schema.sql`
- `Sources/CiderData/LinkedWork/SQLiteWorkRepository.swift`
- `Sources/CiderData/LinkedNotes/LinkedNoteService.swift`
- `Sources/CiderUI/LinkedWork/LinkedWorkModel.swift`
- `Sources/CiderUI/LinkedWork/LinkedRoute.swift`
- `Sources/CiderUI/LinkedWork/FeatureEntryPoints.swift`
- `Sources/CiderCLI/main.swift`
- `Tests/CiderLinkedWorkTests/LinkedContractTests.swift`
- `Tests/CiderLinkedWorkTests/Fixtures/linked-v1.json`
- `Tests/CiderLinkedWorkTests/Fixtures/legacy-workspace-v1.json`
- `Tests/CiderLinkedWorkTests/Support/FixtureRepository.swift`
- `Tests/CiderLinkedWorkTests/Support/FixtureNoteAccess.swift`
- `Tests/CiderIntegrationTests/LinkedIntegrationContractTests.swift`
- `docs/plans/linked-work/01-contracts.md`

Do not touch: `App/AppModel.swift`, `Features/Today/TodayView.swift`, `Sources/CiderData/AgentEventStore.swift` and production migration/observer behavior.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `docs/plan/05-linked-todos.md`: relationship model, completion, journal and CLI sections.
- `docs/plans/linked-work/contract-spec.md`: read the entire frozen-surface specification.
- `docs/architecture.md`, `docs/contracts/data.md`: actor/queue isolation and persistence boundaries.
- `Package.swift`, `Sources/CiderDomain/{TaskItem,AppSnapshot,AgentTracking}.swift`, `Sources/CiderData/SnapshotStore.swift`: current values and package wiring.
- `Sources/CiderDomain/AgentOrigin.swift`, `Sources/CiderDomain/AgentQuestion.swift`: reuse existing provenance and question identifiers.
- `Sources/CiderUI/Components/CiderPillPicker.swift`: existing component dependency direction.
- `App/CiderApp.swift`: prove the app import seam without running its lifecycle.

## Precise edits

1. **Domain declarations.** Implement all nine `CiderDomain/LinkedWork` files listed below exactly from `contract-spec.md`. Provide explicit tagged Codable for entity IDs, public initializers and stable raw values. Freeze the task ordering, note identity, host/provider/session identity, append proposal, query bounds, attribution and error shapes. No new environment variables or provider envelope fields.
2. **SQLite module/schema.** Add the SDK `CSQLite` module and executable schema resource. Define exact columns, foreign keys, indices, unique constraints, journal sequencing and migration metadata. Exercise the SQL against a temporary database. Prove connection isolation compiles with Swift 6; do not postpone a compiler workaround to lane 02.
3. **Build targets and seeds.** Register the `cider-cli` build product (packaged as `cider`), new test targets and schema resource in `Package.swift`; exclude future `Integrations` from the root app target. Seed `SQLiteWorkRepository` and `LinkedNoteService` with documented typed methods that explicitly throw `notImplemented`. Seed CLI with a structured unavailable error and nonzero exit. These three implementation files transfer to later owners; their public signatures remain frozen.
4. **UI and journal seams.** Implement `LinkedWorkModel`, `LinkedRoute`, feature entry-point protocols and `WorkJournalIngesting`. The model runs on MainActor, delegates work, preserves local edits on conflict and does not import AppModel/NotesModel. Seed entry points are protocols, not duplicate concrete feature views.
5. **Shared fixtures.** Write canonical JSON and in-memory fakes for the cases in the spec. Fakes honor revision conflicts and bounds needed by independent UI tests. Add `LinkedContractTests` covering Codable round trips, legacy fixture fidelity, enum/error strings, schema constraints and read-only missing-store behavior. Do not freeze tests that require the concrete implementations to keep throwing `notImplemented`; inspect the temporary stub behavior during this phase and test stable protocol guarantees instead. Add `LinkedIntegrationContractTests` to prove `@testable import CiderApp` compiles without launching the app. If executable import is unsupported, resolve the seam locally before allowing worktrees.
6. **Freeze.** The coordinator reconciles discovered contract gaps in the spec and affected plans, commits the declarations, checks a clean tree, and records the exact post-contract base. Only then may 02–04 start. A written plan alone does not satisfy this gate.

## Constraints

Preserve existing `AgentEvent`, hook helper, `TaskItem` and legacy JSON compatibility. No live DB migration or user configuration changes. Do not make empty implementations look successful. Keep schema/protocol tests synthetic. The coordinator may amend coordinator-owned plan/spec/ownership files to close a discovered contract gap before freeze; record why. Re-validate concurrent ownership after any amendment.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift build --product cider-cli
swift build --product cider-events
swift test
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- All shared declarations compile, schema and fixtures agree, the app test seam works, all prior tests pass, and no production feature is routed to a stub. The recorded round base contains these files and the plan set.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Define linked work contracts and package seams**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

- Kept the root app target's existing explicit `sources: ["App", "Features"]` boundary instead of adding an exclude for the absent Integrations directory. Why: the source boundary already excludes it, and a nonexistent exclude produces a SwiftPM warning. Affects: Package.swift only; 08 can add its directory without changing the manifest.
- Added the queue-isolated internal WorkDatabaseExecutor proof in the owned repository seed and froze its test seams. Why: this demonstrates the actual SDK pointer/executor boundary before 02, without implementing the store or using unchecked concurrency. Affects: 02 retains or moves this internal implementation while preserving contract tests.
- Pinned concrete defaults, STRICT SQL types, request hashes and batch caps in the shared contract. Why: these were intentionally unresolved until this local phase. Affects: later store/CLI/journal lanes consume the compiled declarations and freeze details.

- Renamed the SwiftPM CLI product to `cider-cli`; packaging still exposes `Contents/Helpers/cider`. Why: `Cider` and `cider` share an inode on this case-insensitive filesystem, so a later app/test link overwrote the CLI executable. The smoke test started an app instance, which was stopped by its exact test PID. Affects: Package.swift and the build/verification commands in 08/09; public CLI spelling is unchanged.

## Handoff evidence

All three products build: Cider, cider-cli and cider-events. The full suite passes 62 tests, including the original 53 plus eight linked-contract checks and the app-import seam. Checks cover SDK SQL constraints/cascades/cursor monotonicity, queue isolation, missing read-only stores, Codable/legacy fidelity, query/revision conflicts, idempotency, retained history, note append conflicts and stale UI reads. The CLI seed returns structured `unavailable` with exit 4. No app deployment or production migration/hook/skill installation was performed. The CLI smoke check briefly started a test app instance because of the case-insensitive product collision described below; that instance was terminated and the build name corrected. Exact implementation/base IDs are recorded by the coordinator in the overview.

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/01-contracts.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 01 on `linked-work/01-contracts`. Run locally as the coordinator; do not create a lane worktree for this plan. Goal: Create the compiled shared types, SQLite schema, protocol fakes and package seams that all later lanes will consume. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift build --product cider-cli; swift build --product cider-events; swift test; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
