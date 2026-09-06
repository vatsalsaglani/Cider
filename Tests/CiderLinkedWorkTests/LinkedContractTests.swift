import Testing
import Foundation
import CSQLite
@testable import CiderData
import CiderDomain
import CiderUI

@Suite struct LinkedContractTests {
    @Test func sqliteSchemaIsolationAndConstraints() async throws {
        let io = WorkDatabaseExecutor()
        try await io.open(path: ":memory:", readOnly: false)
        try await io.perform { db in
            #expect(!Thread.isMainThread)
            let schema = try String(contentsOf: WorkDatabaseExecutor.schemaURL, encoding: .utf8)
            #expect(sqlite3_exec(db, "PRAGMA foreign_keys=ON;" + schema, nil, nil, nil) == SQLITE_OK)
            #expect(try Self.integer(db, "PRAGMA user_version") == 1)
            #expect(try Self.integer(db, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'") == 14)
            let seed = """
            INSERT INTO tasks VALUES ('t1','Task','','2026-09-06',NULL,'planned',0,0,1);
            INSERT INTO tasks VALUES ('t2','Other','','2026-09-06',NULL,'done',0,1,1);
            INSERT INTO chats VALUES ('h','codex','s','Same title','/fixtures',NULL,0,'turn','Working',NULL);
            INSERT INTO chats VALUES ('h','codex','s2','Same title','/fixtures',NULL,0,'turn','Working',NULL);
            INSERT INTO task_chat_links VALUES ('l1','t1','h','codex','s',NULL,0,NULL,'turn',1);
            INSERT INTO folder_roots VALUES ('r','/fixtures',1);
            INSERT INTO notes VALUES ('n','r','test.md',NULL,1,0);
            INSERT INTO task_note_links VALUES ('nl','t1','n','evidence',0);
            """
            #expect(sqlite3_exec(db, seed, nil, nil, nil) == SQLITE_OK)
            #expect(sqlite3_exec(db, "UPDATE tasks SET revision='text'", nil, nil, nil) == SQLITE_CONSTRAINT)
            for invalid in [
                "UPDATE tasks SET status='verified' WHERE id='t1'",
                "UPDATE tasks SET title='' WHERE id='t1'",
                "INSERT INTO task_note_links VALUES ('missing','t1','absent','context',0)",
                "INSERT INTO task_chat_links VALUES ('duplicate','t1','h','codex','s',NULL,1,NULL,NULL,1)",
                "UPDATE task_note_links SET role='unknown'",
                "INSERT INTO mutation_receipts VALUES ('c','hash','not json')",
                "INSERT INTO criteria VALUES ('c','t1',200,'Check',0,0)"
            ] { #expect(sqlite3_exec(db, invalid, nil, nil, nil) == SQLITE_CONSTRAINT) }
            let journal = """
            INSERT INTO journal(id,task_id,link_id,host_id,provider,session_id,source_event_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution)
            VALUES ('j','t1','l1','h','codex','s','e','key',0,0,'response','Preview',1,'identifiedTurn');
            """
            #expect(sqlite3_exec(db, journal, nil, nil, nil) == SQLITE_OK)
            #expect(sqlite3_exec(db, journal.replacingOccurrences(of: "'j'", with: "'j2'"), nil, nil, nil) == SQLITE_CONSTRAINT)
            #expect(sqlite3_exec(db, "UPDATE journal SET task_id='t2'", nil, nil, nil) == SQLITE_CONSTRAINT)
            #expect(sqlite3_exec(db, "UPDATE task_chat_links SET ended_at=1 WHERE id='l1'", nil, nil, nil) == SQLITE_OK)
            #expect(try Self.integer(db, "SELECT count(*) FROM journal") == 1)
            #expect(sqlite3_exec(db, "INSERT INTO task_chat_links VALUES ('l2','t1','h','codex','s',NULL,2,NULL,NULL,1)", nil, nil, nil) == SQLITE_OK)
            #expect(sqlite3_exec(db, "DELETE FROM tasks WHERE id='t1'", nil, nil, nil) == SQLITE_OK)
            #expect(try Self.integer(db, "SELECT count(*) FROM journal") == 0)
            #expect(try Self.integer(db, "SELECT count(*) FROM chats") == 2)
            #expect(try Self.integer(db, "SELECT count(*) FROM notes") == 1)
            #expect(try Self.integer(db, "SELECT count(*) FROM task_note_links") == 0)
            #expect(sqlite3_exec(db, "INSERT INTO journal(id,task_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES ('new','t2','new',1,1,'userNote','Review',0,'userSelected')", nil, nil, nil) == SQLITE_OK)
            #expect(try Self.integer(db, "SELECT sequence FROM journal") == 2)
        }
        await io.close()
    }
    @Test func readOnlyMissingStoreDoesNotCreateFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "missing.sqlite")
        let io = WorkDatabaseExecutor()
        await #expect(throws: WorkStoreError.unavailable) { try await io.open(path: url.path, readOnly: true) }
        await #expect(throws: WorkStoreError.self) { try await SQLiteWorkRepository.open(at: url, access: .cliReadOnly) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        await io.close()
    }
    @Test func fixturesAndLegacyProjectionRoundTrip() throws {
        let fixture = try LinkedFixture.load()
        let copy = try JSONDecoder().decode(LinkedFixture.self, from: JSONEncoder().encode(fixture))
        #expect(copy.tasks == fixture.tasks)
        #expect(copy.chats == fixture.chats)
        #expect(copy.journal == fixture.journal)
        #expect(copy.episodes == fixture.episodes)
        let url = Bundle.module.url(forResource: "legacy-workspace-v1", withExtension: "json", subdirectory: "Fixtures")!
        let legacy = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: url))
        #expect(legacy.tasks == fixture.tasks.map(\.legacyItem))
        #expect(legacy.notch == fixture.notch)
        #expect(fixture.chats[0].title == fixture.chats[1].title)
        #expect(fixture.chats[0].identity != fixture.chats[1].identity)
        #expect(fixture.noteLinks.filter { $0.noteID == fixture.notes[1].id }.count == 2)
        #expect(fixture.journal[0].kind == .question)
        #expect(fixture.chatLinks.contains { $0.endedAt != nil })
    }
    @Test func stableIdentityAndVocabulary() throws {
        let fixture = try LinkedFixture.load()
        let ids: [LinkedEntityID] = [.task(fixture.tasks[0].id), .note(fixture.notes[0].id), .chat(fixture.chats[0].identity)]
        for id in ids {
            let data = try JSONEncoder().encode(id)
            #expect(try JSONDecoder().decode(LinkedEntityID.self, from: data) == id)
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["kind"] as? String == id.kind.rawValue)
        }
        let mut = WorkMutation(change: .attachChat(taskID: fixture.tasks[0].id, chat: fixture.chats[0], role: "Review", initialTurnID: nil))
        #expect(try JSONDecoder().decode(WorkMutation.self, from: JSONEncoder().encode(mut)) == mut)
        #expect(WorkTaskStatus.allCases.map(\.rawValue) == ["planned","inProgress","blocked","readyForReview","done"])
        #expect(WorkStoreError.allCases.map(\.code) == ["notFound","conflict","invalidInput","readOnly","unavailable","busy","unsupportedSchema","migrationFailed","outsideRoot","fileChanged","outputLimit","notImplemented"])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(LinkedEntityID.self, from: Data(#"{"kind":"task","id":"invalid"}"#.utf8)) }
    }
    @Test func fixtureRevisionsPaginationAndIdempotency() async throws {
        let fixture = try LinkedFixture.load(); let repo = FixtureRepository(fixture)
        let first = try await repo.tasks(TaskQuery(limit: 1))
        let cursor = try #require(first.nextCursor)
        let second = try await repo.tasks(TaskQuery(cursor: cursor, limit: 1))
        #expect(first.items[0].id != second.items[0].id)
        await #expect(throws: WorkStoreError.conflict) { try await repo.tasks(TaskQuery(search: "changed", cursor: cursor, limit: 1)) }
        var draft = fixture.tasks[0]; draft.descriptionMarkdown = "Updated"
        let mutation = WorkMutation(change: .saveTask(task: draft))
        let receipt = try await repo.apply(mutation)
        #expect(try await repo.apply(mutation) == receipt)
        await #expect(throws: WorkStoreError.conflict) { try await repo.apply(WorkMutation(change: .saveTask(task: draft))) }
        await #expect(throws: WorkStoreError.conflict) { try await repo.tasks(TaskQuery(cursor: cursor, limit: 1)) }
        #expect(try await repo.detail(draft.id).task.status == .inProgress)
        #expect(try await repo.detail(draft.id).task.revision == 2)
        await #expect(throws: WorkStoreError.invalidInput) { try await repo.tasks(TaskQuery(limit: 0)) }
    }
    @Test func fixtureDetachPreservesHistoryAndNoteBytes() async throws {
        let fixture = try LinkedFixture.load(); let repo = FixtureRepository(fixture)
        _ = try await repo.apply(WorkMutation(change: .detachChat(linkID: fixture.chatLinks[0].id)))
        #expect(try await repo.journal(JournalQuery(taskID: fixture.tasks[0].id)).items == fixture.journal)
        let note = fixture.notes[0]; let files = FixtureNoteAccess(bodies: [note.id: "Original\n"])
        let proposal = try await files.previewAppend(note: note, root: fixture.folders[0], markdown: "Checkpoint\n")
        await files.replaceBody(noteID: note.id, markdown: "External edit\n")
        await #expect(throws: WorkStoreError.fileChanged) { try await files.applyAppend(proposal) }
        #expect(try await files.read(note, root: fixture.folders[0], maxBytes: 65536).markdown == "External edit\n")
        _ = try await repo.apply(WorkMutation(change: .deleteTask(taskID: fixture.tasks[0].id)))
        #expect(try await repo.note(note.id) == note)
        #expect(try await repo.journal(JournalQuery(taskID: fixture.tasks[1].id)).items.isEmpty)
    }
    @MainActor @Test func staleReadsCannotOverwriteNewSelectionAndBusyRemainsAccurate() async throws {
        let fixture = try LinkedFixture.load(); let repo = FixtureRepository(fixture)
        let model = LinkedWorkModel(repository: repo, noteAccess: FixtureNoteAccess())
        await repo.holdNextTaskRead()
        let old = Task { await model.refresh(TaskQuery()) }
        while !(await repo.readIsHeld) { await Task.yield() }
        await model.refresh(TaskQuery(search: "no matching task"))
        #expect(model.taskPage?.items.isEmpty == true)
        #expect(model.busy)
        await repo.releaseTaskRead(); await old.value
        #expect(model.taskPage?.items.isEmpty == true)
        #expect(!model.busy)
        await model.loadDetail(fixture.tasks[0].id)
        let staleDraft = fixture.tasks[0]
        _ = try await repo.apply(WorkMutation(change: .saveTask(task: staleDraft)))
        #expect(await model.perform(WorkMutation(change: .saveTask(task: staleDraft))) == false)
        #expect(model.error?.contains("draft is still here") == true)
        #expect(model.selectedDetail?.task == staleDraft)
    }
    @Test func validationAndExplicitCompletion() throws {
        var task = WorkTask(title: "Review", status: .blocked)
        #expect(task.legacyItem.completed == false)
        task.toggleCompletion(); #expect(task.status == .done)
        task.toggleCompletion(); #expect(task.status == .planned)
        #expect(throws: WorkStoreError.outputLimit) {
            try WorkLimits.validate(batch: JournalBatch(expectedRevision: 0, entries: [], episodes: [], processedEventIDs: Array(repeating: UUID(), count: 2049)))
        }
        task.descriptionMarkdown = String(repeating: "x", count: 65537)
        #expect(throws: WorkStoreError.invalidInput) { try WorkLimits.validate(task: task) }
        #expect(throws: WorkStoreError.invalidInput) { try WorkLimits.validate(graph: GraphQuery(scope: .local(entity: .task(task.id), depth: 3))) }
    }
    private static func integer(_ db: OpaquePointer, _ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw WorkStoreError.invalidInput }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw WorkStoreError.notFound }
        return Int(sqlite3_column_int64(statement, 0))
    }
}
