# Plan 02 — Transactional store and migration

Branch: `linked-work/02-store`. Depends on: 01.
Runs in parallel with: 03, 04.

## Goal

Implement the one transactional source of truth for TODOs, chat assignments, notes and durable checkpoints. Import the legacy workspace without losing IDs, day/order/completion or notch settings. Expose the frozen read/mutation APIs to independent UI and CLI consumers; do not switch the running app in this lane.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `App/AppModel.swift:22`: `store = SnapshotStore(url: storeURL ?? root.appending(path: "workspace.json"))`. The surrounding root is named `Cinder`; importing only a new Cider path would miss existing tasks.
- `App/AppModel.swift:49`: `private func commit(_ change: (inout AppSnapshot) -> Void) async -> Bool`. Task persistence is currently a whole JSON snapshot guarded inside one app process.
- `Sources/CiderData/SnapshotStore.swift:5`: `public actor SnapshotStore {`. An actor alone does not provide the cross-process transactional read surface needed by the CLI.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Sources/CiderData/LinkedWork/SQLiteWorkRepository.swift`
- `Sources/CiderData/LinkedWork/WorkDatabaseIO.swift`
- `Sources/CiderData/LinkedWork/WorkMigration.swift`
- `Sources/CiderData/LinkedWork/WorkQueries.swift`
- `Sources/CiderData/LinkedWork/WorkMutations.swift`
- `Sources/CiderData/LinkedWork/WorkJournalTransactions.swift`
- `Sources/CiderData/LinkedWork/WorkGraphQueries.swift`
- `Tests/CiderLinkedWorkTests/LinkedStoreTests.swift`
- `Tests/CiderLinkedWorkTests/LinkedMigrationTests.swift`
- `docs/plans/linked-work/02-store.md`

Do not touch: `Package.swift`, `Sources/CiderDomain/LinkedWork/`, `Schema.sql`, `App/AppModel.swift`, `Features/Notes/NotesModel.swift` and any live DB.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `contract-spec.md`: repository, mutations, SQL, bounds and migration sections; actual declarations and SQL created by 01 take precedence after freeze.
- `Sources/CiderDomain/LinkedWork/` and `Sources/CiderData/LinkedWork/Schema.sql`: compiled inputs from 01; read, do not edit.
- `Sources/CiderDomain/{AppSnapshot,TaskItem,LocalDay}.swift`, `Sources/CiderData/SnapshotStore.swift`: import semantics.
- `App/AppModel.swift`: existing commit/ordering behavior, read-only in this lane.
- `Tests/CiderLinkedWorkTests/Fixtures/` and `Support/`: shared synthetic cases.

## Precise edits

1. **Repository/IO.** Fill `SQLiteWorkRepository` and keep blocking SQLite/file work in `WorkDatabaseIO`'s compiler-checked private utility boundary. Open writable app connections with foreign keys, WAL and bounded busy handling; a CLI read-only open never creates/migrates a missing DB. Reject unknown schema versions without altering files.
2. **Migration.** `WorkMigration` takes explicit legacy URL/root paths. Verify a backup hash, decode before writing, preserve task UUIDs and array order in `sortOrder`, map completion, register folder roots and notch preferences, and commit the migration marker with the import. Repeat startup is idempotent. A failed import leaves the source intact and does not replace a valid destination. Implement a callable internal recovery export exercised by tests so the coordinator can preserve post-migration edits when rolling back; do not write the legacy file on normal saves.
3. **Queries/mutations.** Implement every frozen operation in `WorkQueries` and `WorkMutations`: task detail, query-bound pagination, folders/notes/backlinks, attachment intervals, metadata refresh of known chats, explicit statuses and row/store revisions. Make command retries return their stored receipt. Validate reference identities and limits before writes. Delete only task-owned records; linked notes and chats survive.
4. **Journal transactions.** `WorkJournalTransactions` commits entries, assignment episodes, processed source IDs and monotonic sequences together. Check attribution revision inside the transaction. Keep source replay and stable-turn duplicate checks separate; one source can legitimately contribute to multiple explicitly assigned TODOs.
5. **Graph queries.** `WorkGraphQueries` projects saved relationships with deterministic ordering, filters, bounded local expansion and endpoint-preserving limits. Include related note-to-note edges only when explicitly indexed. Return `truncated` when appropriate; no inferred similarity edges. Graph and backlinks must derive from the same records.
6. **Tests.** Add `LinkedStoreTests` and `LinkedMigrationTests`. Use separate connections/process-style readers to exercise stale edits, busy timeout, transaction failure, read-only behavior, duplicate commands, concurrent unlink/journal commit, foreign-key retention and migration retry. Do not just compare generated SQL strings.

## Constraints

Schema.sql, Domain/UI declarations, Package.swift and shared fixtures are frozen. If the SQL cannot express required behavior, record CONTRACT CHANGE NEEDED; do not quietly add columns. Avoid scanning live Application Support. Maintain limits for ordinary lists and journal batches; historical journal rows are not subject to the observer cache's expiry. The app cutover belongs to 05.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift test --filter LinkedContractTests
swift test --filter LinkedStoreTests
swift test --filter LinkedMigrationTests
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- All frozen repository methods have real implementations and transactional failure tests. Migration is lossless/idempotent in fixtures; read-only access succeeds without Cider running; graph/backlinks agree. Public stub errors are gone from this repository.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Add transactional linked work store and legacy migration**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

None. The frozen schema and repository contracts were sufficient. The recovery
export remains an internal callable repository capability because its public
signature was not part of the frozen surface.

## Lane handoff

- Implemented SQLite connection confinement, schema/read-only checks, legacy
  import/backup/recovery export, repository reads/mutations, journal batches and
  graph projection in the owned data files.
- Added temporary-fixture store and migration tests. Native relaunch, live
  provider interaction and hardware checks remain coordinator integration gates.

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/02-store.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 02 on `linked-work/02-store`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Implement the one transactional source of truth for TODOs, chat assignments, notes and durable checkpoints. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift test --filter LinkedContractTests; swift test --filter LinkedStoreTests; swift test --filter LinkedMigrationTests; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
