# Shared contract to build in plan 01

Plan 01 has compiled these declarations, schema and fixtures. The concrete repository and note service deliberately remain unavailable seeds until 02 and 04; CLI queries land in 08. The implementation commit is recorded in the overview before worktrees start. The checked-in Swift declarations now pin initializer argument order and defaults. A required correction is recorded here by the coordinator before that freeze. Later lanes may change implementation bodies only in their owned files; they never change these shared declarations.

Source baseline: `192b50f0a83c1163009d229026ae1733c3f229a9`. Product source: `docs/plan/05-linked-todos.md`. Existing `TaskItem`, `AppSnapshot`, `AgentEvent` and `TrackedSession` remain backward compatible. No provider hook schema change is needed for this plan set.

## Domain values

All values below live in `Sources/CiderDomain/LinkedWork/`, are `Sendable` and `Codable`, and have public initializers. Identity/value types also conform to `Hashable` where used as dictionary or graph keys. Dates use Foundation `Date`; planned days keep `LocalDay`. Use explicit string raw values for persisted enums.

| File | Exact exported values and required fields |
| --- | --- |
| `Identity.swift` | `ChatIdentity(hostID: UUID, provider: TrackedProvider, sessionID: String)`; `ChatReference(identity: ChatIdentity, title: String?, directory: String, origin: AgentOrigin?, observedAt: Date?, currentTurnID: String?, execution: AgentExecution, attention: String?)`; `LinkedEntityKind`: `task`, `chat`, `note`; `LinkedEntityID` with `.task(UUID)`, `.chat(ChatIdentity)`, `.note(UUID)` and an explicit tagged Codable representation |
| `Tasks.swift` | `WorkTask(id: UUID, title: String, descriptionMarkdown: String, plannedDay: LocalDay, dueAt: Date?, status: WorkTaskStatus, criteria: [WorkCriterion], createdAt: Date, sortOrder: Int64, revision: Int64)`; `WorkTaskStatus`: `planned`, `inProgress`, `blocked`, `readyForReview`, `done`; `WorkCriterion(id: UUID, text: String, checked: Bool, updatedAt: Date)`; `WorkTask.legacyItem: TaskItem` maps only `done` to completed |
| `Notes.swift` | `FolderReference(id: UUID, path: String, available: Bool)`; `NoteReference(id: UUID, rootID: UUID, relativePath: String, fileIdentity: Data?, available: Bool, modifiedAt: Date?)`; `NoteRole`: `plan`, `context`, `evidence`; `NoteFileSnapshot(noteID: UUID, markdown: String, sha256: String, modifiedAt: Date, truncated: Bool)`; `NoteDocumentLink(id: UUID, sourceID: UUID, targetID: UUID, fragment: String?)` |
| `Links.swift` | `TaskChatLink(id: UUID, taskID: UUID, chat: ChatIdentity, role: String?, startedAt: Date, endedAt: Date?, initialTurnID: String?, revision: Int64)`; `TaskNoteLink(id: UUID, taskID: UUID, noteID: UUID, role: NoteRole, createdAt: Date)`; `AssignmentEpisode(id: UUID, linkID: UUID, sourceStartID: UUID, turnID: String?, startedAt: Date, endedAt: Date?)` |
| `Journal.swift` | `JournalKind`: `response`, `question`, `questionResolved`, `userNote`; `JournalEntry(id: UUID, sequence: Int64, taskID: UUID, linkID: UUID?, chat: ChatIdentity?, sourceEventID: UUID?, sourceTurnID: String?, questionID: String?, sourceKey: String, occurredAt: Date, receivedAt: Date, kind: JournalKind, text: String, previewOnly: Bool, attribution: JournalAttribution)`; `JournalAttribution`: `identifiedTurn`, `observedEpisode`, `userSelected`; `JournalDraft` has the same fields except `sequence`; `AttributionSnapshot(revision: Int64, links: [TaskChatLink], episodes: [AssignmentEpisode], processedEventIDs: [UUID])`; `JournalBatch(expectedRevision: Int64, entries: [JournalDraft], episodes: [AssignmentEpisode], processedEventIDs: [UUID])`; `JournalReceipt(revision: Int64, inserted: Int, duplicate: Int)` |
| `Graph.swift` | `GraphScope`: `.workspace(rootID: UUID?)`, `.local(entity: LinkedEntityID, depth: Int)`; `GraphQuery(scope: GraphScope, includeDone: Bool, includeIsolated: Bool, nodeKinds: [LinkedEntityKind], statuses: [WorkTaskStatus], activeChatsOnly: Bool, providers: [TrackedProvider], search: String, nodeLimit: Int, edgeLimit: Int)`; `GraphNode(id: LinkedEntityID, title: String, subtitle: String?, taskStatus: WorkTaskStatus?, execution: AgentExecution?, attention: String?, available: Bool)`; `GraphEdgeKind`: `contributes`, `noteContext`, `noteEvidence`, `notePlan`, `documentLink`; `GraphEdge(id: UUID, source: LinkedEntityID, target: LinkedEntityID, kind: GraphEdgeKind)`; `GraphSnapshot(revision: Int64, nodes: [GraphNode], edges: [GraphEdge], truncated: Bool)` |
| `Commands.swift` | `WorkMutation(commandID: UUID, expectedRevision: Int64?, change: WorkChange)`; `MutationReceipt(revision: Int64, entity: LinkedEntityID?)`; enums and payloads below |
| `Repository.swift` | Repository protocols, query/results, store errors and access mode below |
| `NoteAccess.swift` | Note file interface and append proposal below |

A chat key includes the stored local host UUID, provider and full session ID. Do not use a title, workspace path, short ID or PID as the key. Store the host UUID once in database metadata. Chat metadata updates are bounded snapshots of already registered chat identities; they cannot change contributor assignments or the user-owned task status. Current observer events are local; do not invent account or remote-host data. Related notes through a TODO remain two links, not a direct claim that the chat read that note.

`WorkTask` is the canonical database row. `TaskItem` is only its compatibility projection for current calendar/notch views and legacy JSON import. Do not persist two competing completion fields. On explicit checkbox reopen, map `done` to `planned`; preserve other statuses when reading, sorting or editing an unrelated field. A response never sets `done` or checks criteria.

## Repository interfaces

`Repository.swift` freezes these async interfaces. Reads must not create or migrate a database. All returned data is bounded and carries a revision or cursor; no transcript bodies enter generic metadata queries.

```swift
public protocol WorkReading: Sendable {
    func info() async throws -> WorkStoreInfo
    func tasks(_ query: TaskQuery) async throws -> WorkPage<WorkTask>
    func detail(_ id: UUID) async throws -> TaskDetail
    func folders() async throws -> [FolderReference]
    func note(_ id: UUID) async throws -> NoteReference
    func notes(_ query: NoteQuery) async throws -> WorkPage<NoteReference>
    func connections(_ entity: LinkedEntityID, limit: Int) async throws -> WorkConnections
    func journal(_ query: JournalQuery) async throws -> WorkPage<JournalEntry>
    func graph(_ query: GraphQuery) async throws -> GraphSnapshot
    func attribution(chats: [ChatIdentity], eventIDs: [UUID]) async throws -> AttributionSnapshot
    func notchPreferences() async throws -> NotchPreferences
}
public protocol WorkRepository: WorkReading {
    func apply(_ mutation: WorkMutation) async throws -> MutationReceipt
    func appendJournal(_ batch: JournalBatch) async throws -> JournalReceipt
}
```

Freeze these query/result fields:

- `WorkStoreInfo(schemaVersion: Int, revision: Int64, hostID: UUID)`.
- `WorkPage<Element: Codable & Sendable>(items: [Element], nextCursor: String?, revision: Int64)`.
- `TaskQuery(day: LocalDay?, includeDone: Bool, search: String, cursor: String?, limit: Int)`.
- `NoteQuery(rootID: UUID?, search: String, cursor: String?, limit: Int)`.
- `JournalQuery(taskID: UUID, afterSequence: Int64?, cursor: String?, limit: Int)`.
- `TaskDetail(task: WorkTask, chats: [ChatReference], chatLinks: [TaskChatLink], notes: [NoteReference], noteLinks: [TaskNoteLink], journalCount: Int64, truncated: Bool, revision: Int64)`.
- `WorkConnections(entity: LinkedEntityID, tasks: [WorkTask], chats: [ChatReference], notes: [NoteReference], edges: [GraphEdge], truncated: Bool, revision: Int64)`.
- `StoreAccess`: `appReadWrite`, `cliReadOnly`. `LegacyImport(workspaceURL: URL, folderPaths: [String])`.
- `SQLiteWorkRepository.open(at: URL, access: StoreAccess, legacy: LegacyImport?) async throws -> SQLiteWorkRepository` is the factory in `Sources/CiderData/LinkedWork/SQLiteWorkRepository.swift`. Its implementation is seeded in 01 and owned by 02 after freeze. It implements `WorkRepository`; all mutation calls in read-only mode throw `readOnly`.
- `WorkStoreError` stable codes: `notFound`, `conflict`, `invalidInput`, `readOnly`, `unavailable`, `busy`, `unsupportedSchema`, `migrationFailed`, `outsideRoot`, `fileChanged`, `outputLimit`, `notImplemented`. Associated detail is sanitized and never contains file/note/prompt bodies. `notImplemented` exists only for contract stubs and must be unreachable in the integrated release.

Folder roots are capped at 100; registration beyond the cap reports `outputLimit`. Empty graph filter arrays mean all; `activeChatsOnly` selects freshly observed running or awaiting-input chats, with the existing stale threshold applied before graph construction. Historical chat rows remain available through task connections. Normal list defaults: 100 items; range 1...500. Task detail/connections cap each related collection at 500 and expose `truncated`. Graph defaults/maxima: 250 nodes/600 edges, expandable by an explicit new query up to 1,000/3,000. Local depth 1 or 2 only. Graph limits retain edge endpoints and deterministic ordering; no silent dangling edges. CLI and UI show the bounded result rather than calling it the whole workspace. Cursors bind query identity and revision and reject a changed query/revision with `conflict`, allowing a fresh read. Journal's monotonically increasing `afterSequence` is the stable incremental cursor across writes.

## Mutation payloads

`WorkChange` must freeze these cases, with their labelled payloads, before parallel work:

```swift
case saveTask(task: WorkTask) // revision 0 creates; existing row requires matching task.revision
case deleteTask(taskID: UUID)
case attachChat(taskID: UUID, chat: ChatReference, role: String?, initialTurnID: String?)
case observeChats(chats: [ChatReference]) // update already registered chats only; never attach implicitly
case detachChat(linkID: UUID)
case attachNote(taskID: UUID, noteID: UUID, role: NoteRole)
case detachNote(linkID: UUID)
case registerFolder(folder: FolderReference)
case registerNote(note: NoteReference)
case setFolderAvailable(rootID: UUID, available: Bool)
case replaceDocumentLinks(sourceNoteID: UUID, links: [NoteDocumentLink])
case appendUserNote(taskID: UUID, text: String)
case setNotch(preferences: NotchPreferences)
```

Commands carry a UUID idempotency key and use one transaction. Their returned receipt is stored, so a retry after a lost response returns the same result. `expectedRevision` optionally guards the whole store; task edits always guard the row revision. Empty task titles and invalid references fail before mutation. Caps: title 500 characters, description 64 KiB UTF-8, 200 criteria with 1,000-character text, contributor role 120 characters, user journal note 16 KiB. Generated previews keep the observer's 600-character cap. Batch/event limits are checked before allocation/SQL execution.

Duplicate active chat attachment for the same task/chat is idempotent; use an explicit detach/new attachment to change assignment scope. Duplicate task/note attachment updates its role deliberately while preserving the link identity. `detachChat` closes its interval using repository time and retains journal history. Unlinking a note never deletes its file. Deleting a TODO transactionally removes its owned links/journal, leaves notes/chats intact and requires a concrete UI confirmation displaying the affected journal count. Neither CLI v1 nor observer may delete tasks.

## Durable journal and attribution

Freeze these rules in fixtures as well as prose:

1. Read a bounded spool batch; commit attributed journal entries; only then save/prune the rolling ledger and acknowledge/remove that batch. If the journal commit fails, acknowledge nothing. A crash after the journal commit retries the same IDs without duplicate checkpoints.
2. `appendJournal` checks the attribution snapshot's store revision inside its transaction. A concurrent attach/detach causes a conflict and recomputation, not application against stale links. Entries, assignment episodes, processed IDs and revision update commit together.
3. A new link applies to upcoming observed turns by default. The attach sheet may include the current turn only when an exact `initialTurnID` is known and the user chooses it. With no turn ID, wait for a subsequent `UserPromptSubmit` before opening an observed episode; label such attribution accordingly. The UI explains when tracking starts.
4. A Stop must match that link's identified turn or an open observed episode. A delayed old identified turn cannot enter a new assignment. Missing turn IDs cannot prove provider chronology; do not guess from cwd. Ambiguous outputs stay unassigned, available only for explicit user-selected import later.
5. Child events appear under a linked parent's episode only if parent/child identity can be proven; do not create new TODOs. Independent chats in one directory never share an episode automatically.
6. Durable dedupe uses source event UUID for replay. When available, also use `(task, link, host, provider, session, child, turn, kind)` for one Stop response checkpoint per assigned TODO. Dedupe never drops a legitimate copy for another explicitly linked TODO. Questions use their stable request/question IDs; persist `questionID` on each question and resolution so pairing never relies on message text. Current hooks generate a fresh UUID per invocation; without provider turn/request identity, separate hook invocations cannot be perfectly deduplicated. Record this limitation rather than claiming exactly-once provider delivery.
7. Stop/Question previews retain source wording, timestamps and `previewOnly=true`. A question reply records resolution identifiers, never the user's answer body. Full output capture, auto-summary writes and agent mutations are deferred beyond this core plan set.
8. Do not prune the durable TODO journal with the 30-event/24-hour activity cache. Its lifetime is until explicit user deletion. The spool's current 2,048-file ceiling is still a bounded-offline limitation; show recovery errors, not invented missing history.

## SQLite schema and migration

Freeze executable `Sources/CiderData/LinkedWork/Schema.sql` in 01. Use the macOS SDK SQLite library through `Sources/CSQLite/{module.modulemap,shim.h}`; no package download or new third-party ORM is needed. The contract phase verifies the SDK module with Swift 6 before declaring it frozen.

Tables and keys: `metadata` (schema_version/revision/host_id/migration_source_hash), `tasks` (UUID primary key, fields above, row revision), `criteria` (UUID, task FK, position), `chats` (host/provider/session composite key plus metadata), `task_chat_links` (UUID, task/chat FKs, interval, initial turn, revision), `folder_roots` (UUID), `notes` (UUID, root FK, relative path/file identity), `task_note_links` (UUID, task/note FKs, role), `note_document_links` (UUID, source/target note FKs, fragment), `journal` (UUID, integer sequence unique, task/link/source fields), `assignment_episodes` (UUID, link FK and correlation fields), `processed_events` (source UUID primary key), `mutation_receipts` (command UUID primary key/result), and `preferences` (key/value, including notch).

Pin exact column types, nullability, CHECK/UNIQUE/FK actions and indices in SQL in 01. Add indices for day/status, task links, note backlinks, chat assignments and task journal sequence. Closing links cannot cascade-delete their evidence. Task deletion may cascade only task-owned rows. Use transactions, foreign_keys=ON, WAL in writable mode, bounded busy retry and an explicit busy error. Each database call does its synchronous work on a dedicated utility queue, keeping connection pointers inside that boundary; use a compiler-checked isolation wrapper around the queue-confined connection; no unchecked Sendable escape and no I/O on MainActor.

Default database: `~/Library/Application Support/Cider/work.sqlite`. The legacy source is **`~/Library/Application Support/Cinder/workspace.json`**, not Cider. Folder roots come from the app's existing `workspaceFolders` preference through an explicit `LegacyImport`; CLI never reads that preference. Map legacy array position to `sortOrder`; preserve task UUIDs, dates, order/completion semantics and notch settings. Legacy JSON/schema errors, permissions and failed migration must leave the source and existing DB intact. Backup the source with a verified hash; import and mark the migration in a transaction exactly once. After plan 05 cutover there is one task writer: the DB. The old snapshot file is a recovery backup, not a second synchronized store. Rollback exports a fresh compatible legacy snapshot including post-migration edits before launching an older app; never blindly restore an old backup over newer tasks.

## Note file interface

`NoteAccess.swift` freezes:

```swift
public protocol LinkedNoteAccess: Sendable {
    func resolve(_ note: NoteReference, root: FolderReference) async throws -> URL
    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) async throws -> NoteFileSnapshot
    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) async throws -> NoteReference
    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) async throws -> NoteAppendProposal
    func applyAppend(_ proposal: NoteAppendProposal) async throws -> NoteFileSnapshot
    func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) async throws -> [NoteDocumentLink]
}
```

`NoteAppendProposal(id: UUID, note: NoteReference, root: FolderReference, expectedHash: String, markdownToAppend: String, preview: String)` is a value, not permission to apply. `LinkedNoteService()` in CiderData implements this protocol; its seeded implementation is owned by 04. Canonical path containment must use path components, reject escaping symlinks, and never infer identities from a matching basename. Bounded UTF-8 reads preserve raw source, report truncation, and do not touch drafts or fetch remote assets. Index only actual Markdown links to known notes under chosen roots; ignore code fences/images/external schemes, preserve fragments. Wiki-link support is deferred.

Creating/appending files uses exclusive creation or file coordination/hash conflict checks. Save the open editor before an explicit append; abort if that save fails. File and DB transactions cannot be one atomic operation: if file creation succeeds but link registration fails, keep the created file and report/retry registration; do not delete user writing. Creating a note does not inject frontmatter. Backlinks are Cider metadata. External rename repair uses file identity when possible, otherwise a visible relink action.

## Shared UI model and navigation

Freeze `Sources/CiderUI/LinkedWork/LinkedWorkModel.swift` as a real MainActor/Observable adapter over the repository protocols, independent of AppModel/NotesModel/AppKit. Properties: `taskPage: WorkPage<WorkTask>?`, `selectedDetail: TaskDetail?`, `availableChats: [ChatReference]`, `error: String?`, `busy: Bool`. Methods:

```swift
init(repository: any WorkRepository, noteAccess: any LinkedNoteAccess)
func refresh(_ query: TaskQuery) async
func loadDetail(_ id: UUID) async
func perform(_ mutation: WorkMutation) async -> Bool
func updateAvailableChats(_ chats: [ChatReference])
```

Expose immutable `repository: any WorkRepository` and `noteAccess: any LinkedNoteAccess` for scoped feature models. Own per-view loading/cancellation/generation checks in those models; do not overwrite another view's result after navigation. On conflicts preserve local drafts and show reload/compare; never silently replace another agent's changes.

`LinkedRoute` cases in `LinkedRoute.swift`: `task(UUID)`, `note(UUID)`, `chat(ChatIdentity)`, `graph(LinkedEntityID?)`, `attachChat(ChatReference)`, `attachNote(UUID)`, `chooseNotes(taskID: UUID)`, `createLinkedNote(taskID: UUID)`, `createTaskFromChat(ChatReference)`, `createTaskFromNote(noteID: UUID, excerpt: String?)`, `saveCheckpoint(JournalEntry)`, `copyContext(taskID: UUID, includeNotes: Bool)`. Here `attachNote(UUID)` takes the originating note ID and opens a TODO picker; `chooseNotes(taskID:)` starts from a TODO and opens the note picker. `saveCheckpoint` carries a stored entry whose task/source identities the coordinator verifies before proposing a file write. `copyContext` is explicit clipboard export; 09 supplies its implementation. Plan 05's scene coordinator resolves routes through existing note-save and exact-source-app actions. It handles unavailable/historical sources explicitly. Plan 09 adds the graph route implementation.

`FeatureEntryPoints.swift` declares MainActor SwiftUI `View` protocols with these required initializers, allowing consumers to compile against the contract before app wiring. Implementations live in lane-owned files:

- `LinkedTaskDetailFeature.init(taskID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void)` → `TaskDetailView` (03).
- `LinkedNoteConnectionsFeature.init(noteID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void)` → `NoteConnectionsView` (04).
- `LinkedGraphFeature.init(model: LinkedWorkModel, focus: LinkedEntityID?, navigate: @escaping (LinkedRoute) -> Void)` → `WorkGraphView` (07).
- `LinkedAgentAccessFeature.init()` → `AgentAccessView` (08), setup UI only and never automatic installation.

Plan 01 also freezes the journal service surface in Repository.swift: `WorkJournalIngesting: Sendable` with `ingest(events: [AgentEvent], hostID: UUID, receivedAt: Date) async throws -> JournalReceipt`. Plan 06 implements `JournalIngestor(repository: any WorkRepository)`. Runtime events use the existing envelope, unmodified.

## Build, fixtures and CLI output

Plan 01 registers CSQLite, CiderData's schema resource, the `cider-cli` build product/target (packaged command name `cider`), `CiderLinkedWorkTests` (Domain/Data/UI dependencies, copied Fixtures) and `CiderIntegrationTests` (app dependency). Prove the executable app can be imported/tested without launching it; if SwiftPM prevents that, resolve the app-composition seam locally before freeze rather than asking lanes to change Package.swift. Existing Cider, cider-events and tests must still build. Stub factories/CLI exit with an explicit unavailable result; they are not packaged as working features until integration.

Freeze synthetic fixtures: `Tests/CiderLinkedWorkTests/Fixtures/linked-v1.json` and `legacy-workspace-v1.json`, plus in-memory protocol fakes under `Support/FixtureRepository.swift` and `FixtureNoteAccess.swift`. Include two same-title chats in one folder, one different provider, one shared note, stale/missing references, a pending question, completed/unfinished tasks, and separate link intervals. No live user's DB, note, hook, or transcript is copied into fixtures.

CLI spelling (08 implements): `cider [--store PATH] todo list [--today] [--json]`, `show ID`, `activity ID [--since N]`, `context ID [--include-notes]`, and `summarize-context --today`. Support `--json` on every command. IDs are exact UUIDs. Default is the path above; no new environment variables. `--store` is explicit local/test scope, not a credential lookup. Read-only commands never run migrations, change settings or launch agents.

JSON envelope: `schemaVersion: 1`, `storeRevision: Int64`, `generatedAt: ISO8601 string`, `data`, `nextCursor: string|null`, `truncated: bool`; errors: `schemaVersion: 1`, `error: {code, message}`. Stable lowercase UUID strings, day strings `YYYY-MM-DD`, enum raw values above. `data` uses the task/detail/journal types above. Context adds `notes: [{reference, content?, sha256?, modifiedAt?, truncated}]` and `throughSequence` per task. Notes default to metadata; content requires `--include-notes`. Default note byte limit 64 KiB, total context 256 KiB, max 20 tasks/notes per bundle. Always report omissions/truncation. Unsaved editor drafts are excluded. Exit codes: 0 success, 2 invalid arguments, 3 not found, 4 unavailable/schema/migration, 5 conflict/busy/fileChanged, 6 I/O/output-limit. JSON diagnostics never print note bodies to stderr.

## Freeze checklist

Before 01 is marked complete: compiled API files cover every table above; schema matches domain fields and journal replay/episode needs; public initializers and enum payload labels are unambiguous; fixtures decode; old 53 tests pass; contract tests pass; no side effects from stubs. Add any corrected details to this spec and the affected lane plans, record the exact post-contract commit in the overview, then create the worktrees. No implementation lane starts from the source baseline alone.

## Plan 01 freeze details

- `WorkDatabaseExecutor` in the seeded repository file proves SDK SQLite access on a `DispatchSerialQueue` custom actor executor, with actor-isolated cleanup and `Sendable` return values. Its internal `open(path:readOnly:)`, `perform`, `close` and `schemaURL` seams are exercised by frozen contract tests. Plan 02 may move their implementation into its owned IO file, retaining these testable names/signatures. No connection pointer crosses the actor boundary.
- SQL uses 14 STRICT tables, `user_version=1`, a singleton metadata row and REAL Unix timestamps. `mutation_receipts.request_hash` binds retries to the original request; reusing an ID for different input is a conflict. Journal sequence uses SQLite AUTOINCREMENT so deleting an entry cannot reuse its cursor. `origin_json`, preferences and receipts require valid JSON. Date validity/path containment and Unicode character caps are additionally validated by repository/file-service boundaries.
- `WorkLimits` fixes list 500, roots 100, source-event batch 2,048, journal entries/episodes per transaction 4,096, attribution rows 4,096, note bytes 65,536 and context bytes 262,144. Attribution reads must fail with `outputLimit` rather than silently drop links/episodes beyond their cap. Ingest smaller source batches when needed, never acknowledge a partially attributed event. Source keys are bounded to 512 UTF-8 bytes. `validate(batch:)`, `validate(task:)`, `validate(limit:)` and `validate(graph:)` are shared guards; foreign-key, identity, cursor and operation-specific validation remain the store's job.
- Task queries default to include completed tasks; graph queries default to hide them. Lists default to 100, graph to 250 nodes/600 edges. Constructors and enums are in the compiled files; no initializer relies on an internal memberwise initializer.
- Domain/fixture Codable retains Foundation reference-date numbers and `LocalDay` objects for compatibility. `LinkedEntityID` explicitly tags `kind` and `id`/`chat`. The separate CLI wire format still requires ISO8601 dates, lowercase UUIDs and day strings; 08 owns that explicit projection in CLIOutput and must not change legacy/domain Codable to achieve it.
- The synthetic fixture supplies `referenceTime` for deterministic freshness (two recent same-title chats, one stale Claude chat). Test fakes implement task/note/link reads, optimistic edits, command replay, query/revision-bound cursors, note hash conflicts and a controlled delayed read. Graph layout/indexing and journal transaction writes are intentionally unsupported in these fakes; those lanes test the real implementations from 02/04. They throw `notImplemented`, never return a misleading successful empty result. These fakes live in test support, not the shipped app.
- `Package.swift` already constrains the root app target to `sources: ["App", "Features"]`; this excludes future Integrations content without an invalid-exclude warning for a directory not created until 08. CSQLite is the SDK system library, and CiderData copies Schema.sql as a module resource. The app test target imports CiderApp successfully without constructing its scenes.

- Build-product names are case-distinct on macOS: `Cider` (app), `cider-cli` (CLI), `cider-events` (observer). Never name the CLI build product `cider`, which aliases `Cider` on common macOS filesystems. Plan 09 copies `cider-cli` into the different directory `Contents/Helpers/cider`; user-facing invocations remain `cider todo ...`.
