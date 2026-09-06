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
