import Testing
import Foundation
import CSQLite
@testable import CiderData
import CiderDomain

@Suite struct LinkedStoreTests {
    @Test func writesAreTransactionalAndRetriesReturnStoredReceipt() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let task = WorkTask(title: "Synthetic transaction", plannedDay: LocalDay(year: 2026, month: 9, day: 6))
        let command = WorkMutation(expectedRevision: 0, change: .saveTask(task: task))
        let receipt = try await store.apply(command)
        #expect(receipt.revision == 1)
        #expect(try await store.apply(command) == receipt)
        var stale = task; stale.revision = 1; stale.title = "First edit"
        _ = try await store.apply(WorkMutation(change: .saveTask(task: stale)))
        await #expect(throws: WorkStoreError.conflict) { try await store.apply(WorkMutation(change: .saveTask(task: stale))) }
        let page = try await store.tasks(TaskQuery(limit: 10))
        #expect(page.items.count == 1)
        #expect(page.items[0].revision == 2)
    }

    @Test func readOnlyStoreNeverMutatesAndTaskDeletionRetainsLinkedEntities() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "work.sqlite")
        let writer = try await SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let task = WorkTask(title: "Retain references")
        _ = try await writer.apply(WorkMutation(change: .saveTask(task: task)))
        let folder = FolderReference(path: "/synthetic")
        _ = try await writer.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let note = NoteReference(rootID: folder.id, relativePath: "context.md")
        _ = try await writer.apply(WorkMutation(change: .registerNote(note: note)))
        _ = try await writer.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: note.id, role: .context)))
        let chat = ChatReference(identity: ChatIdentity(hostID: try await writer.info().hostID, provider: .codex, sessionID: "synthetic"), directory: "/synthetic")
        _ = try await writer.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        _ = try await writer.apply(WorkMutation(change: .deleteTask(taskID: task.id)))
        #expect(try await writer.note(note.id) == note)
        let reader = try await SQLiteWorkRepository.open(at: url, access: .cliReadOnly)
        #expect(try await reader.note(note.id) == note)
        await #expect(throws: WorkStoreError.readOnly) { try await reader.apply(WorkMutation(change: .setNotch(preferences: NotchPreferences()))) }
    }

    @Test func journalChecksAttributionRevisionAndDeduplicatesReplay() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let task = WorkTask(title: "Journal")
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: try await store.info().hostID, provider: .codex, sessionID: "journal"), directory: "/synthetic", currentTurnID: "turn-1", execution: .working)
        _ = try await store.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: "turn-1")))
        let detail = try await store.detail(task.id)
        let link = try #require(detail.chatLinks.first)
        let event = UUID()
        let draft = JournalDraft(taskID: task.id, linkID: link.id, chat: chat.identity, sourceEventID: event, sourceTurnID: "turn-1", sourceKey: "turn-1", occurredAt: .now, receivedAt: .now, kind: .response, text: "Preview", attribution: .identifiedTurn)
        let initial = try await store.info().revision
        let batch = JournalBatch(expectedRevision: initial, entries: [draft], episodes: [], processedEventIDs: [event])
        #expect(try await store.appendJournal(batch).inserted == 1)
        let replay = JournalBatch(expectedRevision: try await store.info().revision, entries: [draft], episodes: [], processedEventIDs: [event])
        #expect(try await store.appendJournal(replay).duplicate >= 1)
        #expect(try await store.journal(JournalQuery(taskID: task.id)).items.count == 1)
    }

    @Test func graphAndBacklinksProjectTheSameSavedRelationships() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let task = WorkTask(title: "Graph source")
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        let folder = FolderReference(path: "/synthetic")
        _ = try await store.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let source = NoteReference(rootID: folder.id, relativePath: "source.md")
        let target = NoteReference(rootID: folder.id, relativePath: "target.md")
        _ = try await store.apply(WorkMutation(change: .registerNote(note: source)))
        _ = try await store.apply(WorkMutation(change: .registerNote(note: target)))
        _ = try await store.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: source.id, role: .evidence)))
        let document = NoteDocumentLink(sourceID: source.id, targetID: target.id)
        _ = try await store.apply(WorkMutation(change: .replaceDocumentLinks(sourceNoteID: source.id, links: [document])))
        let connections = try await store.connections(.note(source.id), limit: 10)
        #expect(connections.tasks.map(\.id) == [task.id])
        let graph = try await store.graph(GraphQuery(includeDone: true, includeIsolated: true, nodeLimit: 10, edgeLimit: 10))
        #expect(graph.edges.contains { $0.id == document.id && $0.kind == .documentLink })
        #expect(graph.edges.contains { $0.source == .note(source.id) && $0.target == .task(task.id) && $0.kind == .noteEvidence })
        let repeated = try await store.graph(GraphQuery(includeDone: true, includeIsolated: true, nodeLimit: 10, edgeLimit: 10))
        #expect(repeated == graph)
    }

    @Test func graphIncludesNoteOnlyNodesSearchAndPreservesPlanRole() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let folder = FolderReference(path: "/synthetic")
        _ = try await store.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let isolated = NoteReference(rootID: folder.id, relativePath: "only-note.md")
        _ = try await store.apply(WorkMutation(change: .registerNote(note: isolated)))
        let matching = try await store.graph(GraphQuery(includeIsolated: true, search: "only-note", nodeLimit: 10, edgeLimit: 10))
        #expect(matching.nodes.map(\.id).contains(.note(isolated.id)))
        let task = WorkTask(title: "Plan relation")
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        _ = try await store.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: isolated.id, role: .plan)))
        let connections = try await store.connections(.note(isolated.id), limit: 10)
        #expect(connections.edges.contains { $0.kind == .notePlan && $0.target == .task(task.id) })
    }

    @Test func sqliteUsesUnixDatesAndRoundTripsEmbeddedNULText() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "work.sqlite"); let date = Date(timeIntervalSince1970: 1_700_000_000)
        let store = try await SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let task = WorkTask(title: "NUL", descriptionMarkdown: "before\u{0}after", createdAt: date)
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        #expect(try await store.detail(task.id).task.descriptionMarkdown == "before\u{0}after")
        let io = WorkDatabaseExecutor(); try await io.open(path: url.path, readOnly: true)
        let stored = try await io.perform { db -> Double in
            var statement: OpaquePointer?; defer { sqlite3_finalize(statement) }
            #expect(sqlite3_prepare_v2(db, "SELECT created_at FROM tasks", -1, &statement, nil) == SQLITE_OK)
            #expect(sqlite3_step(statement) == SQLITE_ROW)
            return sqlite3_column_double(statement, 0)
        }
        #expect(stored == date.timeIntervalSince1970); await io.close()
    }

    @Test func concurrentFirstOpenCreatesOneValidSchema() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "work.sqlite")
        async let first = SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        async let second = SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let stores = try await [first, second]
        let firstInfo = try await stores[0].info(); let secondInfo = try await stores[1].info()
        #expect(firstInfo == secondInfo)
    }

    @Test func localFocusAndRootScopeSurviveUnrelatedLeadingRows() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        for index in 0..<4 { _ = try await store.apply(WorkMutation(change: .saveTask(task: WorkTask(title: "Earlier \(index)", sortOrder: Int64(index))))) }
        let focus = WorkTask(title: "Focused", sortOrder: 99)
        _ = try await store.apply(WorkMutation(change: .saveTask(task: focus)))
        let local = try await store.graph(GraphQuery(scope: .local(entity: .task(focus.id), depth: 1), includeDone: true, includeIsolated: true, nodeLimit: 1, edgeLimit: 1))
        #expect(local.nodes.map(\.id) == [.task(focus.id)])
        let folder = FolderReference(path: "/root")
        _ = try await store.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let note = NoteReference(rootID: folder.id, relativePath: "root.md")
        _ = try await store.apply(WorkMutation(change: .registerNote(note: note)))
        _ = try await store.apply(WorkMutation(change: .attachNote(taskID: focus.id, noteID: note.id, role: .context)))
        let chat = ChatReference(identity: ChatIdentity(hostID: try await store.info().hostID, provider: .codex, sessionID: "root-chat"), directory: "/root")
        _ = try await store.apply(WorkMutation(change: .attachChat(taskID: focus.id, chat: chat, role: nil, initialTurnID: nil)))
        let rooted = try await store.graph(GraphQuery(scope: .workspace(rootID: folder.id), includeDone: true, includeIsolated: true, nodeLimit: 20, edgeLimit: 20))
        #expect(rooted.nodes.map(\.id).contains(.task(focus.id)))
        #expect(rooted.nodes.map(\.id).contains(.chat(chat.identity)))
    }

    @Test func graphDeduplicatesDepthTwoAndAppliesScopedFilters() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let folder = FolderReference(path: "/root")
        _ = try await store.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let note = NoteReference(rootID: folder.id, relativePath: "root.md")
        _ = try await store.apply(WorkMutation(change: .registerNote(note: note)))
        let task = WorkTask(title: "Complete", status: .done)
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        _ = try await store.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: note.id, role: .context)))
        let host = try await store.info().hostID
        let staleClaude = ChatReference(identity: ChatIdentity(hostID: host, provider: .claude, sessionID: "stale"), directory: "/root", observedAt: .distantPast, execution: .working)
        _ = try await store.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: staleClaude, role: nil, initialTurnID: nil)))
        let local = try await store.graph(GraphQuery(scope: .local(entity: .task(task.id), depth: 2), includeDone: true, includeIsolated: true, nodeLimit: 20, edgeLimit: 20))
        #expect(local.edges.filter { $0.kind == .noteContext }.count == 1)
        let hiddenDone = try await store.graph(GraphQuery(scope: .workspace(rootID: folder.id), includeDone: false, includeIsolated: true, nodeLimit: 20, edgeLimit: 20))
        #expect(!hiddenDone.nodes.map(\.id).contains(.task(task.id)))
        let filtered = try await store.graph(GraphQuery(scope: .workspace(rootID: folder.id), includeDone: true, includeIsolated: true, activeChatsOnly: true, providers: [.codex], nodeLimit: 20, edgeLimit: 20))
        #expect(!filtered.nodes.map(\.id).contains(.chat(staleClaude.identity)))
        #expect(filtered.edges.filter { $0.kind == .noteContext }.count == 1)
    }

    @Test func independentWriterLockReturnsBoundedBusyError() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "work.sqlite")
        let store = try await SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let locker = WorkDatabaseExecutor()
        try await locker.open(path: url.path, readOnly: false)
        try await locker.configureWriter()
        try await locker.perform { db in #expect(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK) }
        await #expect(throws: WorkStoreError.busy) { try await store.apply(WorkMutation(change: .saveTask(task: WorkTask(title: "Busy"))) ) }
        try await locker.perform { db in #expect(sqlite3_exec(db, "ROLLBACK", nil, nil, nil) == SQLITE_OK) }
        await locker.close()
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-linked-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
