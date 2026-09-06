import Foundation
import Testing
import CiderDomain
import CiderData
@testable import CiderApp

@Suite @MainActor struct LinkedFoundationTests {
    @Test func taskCutoverPreservesIdentityAndRichFields() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appending(path: "workspace.json")
        var snapshot = AppSnapshot()
        snapshot.tasks = [TaskItem(title: "Fixture task", plannedDay: LocalDay())]
        let bytes = try JSONEncoder().encode(snapshot)
        try bytes.write(to: legacy)
        let app = AppModel(storeURL: root.appending(path: "work.sqlite"), legacyURL: legacy, folderPaths: [])
        await app.load()
        #expect(app.ready)
        let repository = try #require(app.repository)
        var row = try await repository.detail(snapshot.tasks[0].id).task
        row.descriptionMarkdown = "Keep **context**"
        row.status = .blocked
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: row)))
        await app.refresh()
        var item = try #require(app.snapshot.tasks.first)
        item.title = "Edited title"
        #expect(await app.update(item))
        let saved = try await repository.detail(item.id).task
        #expect(saved.status == .blocked)
        #expect(saved.descriptionMarkdown == "Keep **context**")
        await app.toggle(item)
        #expect(try await repository.detail(item.id).task.status == .done)
        #expect(try Data(contentsOf: legacy) == bytes)
        let reopened = AppModel(storeURL: root.appending(path: "work.sqlite"), legacyURL: legacy, folderPaths: [])
        await reopened.load()
        #expect(reopened.snapshot.tasks.first?.id == item.id)
        #expect(reopened.snapshot.tasks.first?.completed == true)
    }

    @Test func failedMigrationNeverEnablesAnEmptyWorkspace() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appending(path: "broken.json")
        try Data("not json".utf8).write(to: legacy)
        let app = AppModel(storeURL: root.appending(path: "work.sqlite"), legacyURL: legacy, folderPaths: [])
        app.dayDraft = "Keep draft"
        await app.load()
        #expect(!app.ready)
        #expect(app.error != nil)
        #expect(!(await app.createTask(app.dayDraft, day: LocalDay())))
        #expect(app.dayDraft == "Keep draft")
    }
    @Test func dirtyNoteNavigationPreservesDraftOnConflict() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appending(path: "first.md"), second = root.appending(path: "second.md")
        try "Original".write(to: first, atomically: true, encoding: .utf8)
        try "Second".write(to: second, atomically: true, encoding: .utf8)
        let notes = NotesModel(folders: [root])
        await notes.open(first)
        notes.body = "My draft"
        try "External edit".write(to: first, atomically: true, encoding: .utf8)
        await notes.open(second)
        #expect(notes.selected == first)
        #expect(notes.body == "My draft")
        #expect(notes.error != nil)
        #expect(try String(contentsOf: first, encoding: .utf8) == "External edit")
    }

    @Test func checkpointPersistsReplacementIdentityAcrossRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "context.md")
        try "# Context".write(to: file, atomically: true, encoding: .utf8)
        let database = root.appending(path: "work.sqlite")
        let repository = try await SQLiteWorkRepository.open(at: database, access: .appReadWrite)
        let notes = NotesModel(folders: [root])
        let coordinator = LinkedWorkCoordinator(notes: notes)
        try await coordinator.start(repository: repository)
        await notes.open(file)
        let entry = JournalEntry(sequence: 1, taskID: UUID(), sourceKey: "fixture", occurredAt: .now,
            receivedAt: .now, kind: .response, text: "Fixture checkpoint", attribution: .userSelected)
        await coordinator.previewCheckpoint(entry)
        let noteID = try #require(coordinator.checkpointProposal?.note.id)
        await coordinator.confirmCheckpoint()
        #expect(coordinator.checkpointProposal == nil)
        let reopened = try await SQLiteWorkRepository.open(at: database, access: .cliReadOnly)
        let reference = try await reopened.note(noteID)
        let folder = try #require(try await reopened.folders().first)
        let snapshot = try await LinkedNoteService().read(reference, root: folder, maxBytes: WorkLimits.noteBytes)
        #expect(snapshot.markdown.contains("Fixture checkpoint"))
        #expect(reference.fileIdentity == snapshot.fileIdentity)
        #expect(notes.body.contains("Fixture checkpoint"))
    }

    @Test func paginationKeepsTasksBeyondTheFirstPage() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appending(path: "work.sqlite")
        let repository = try await SQLiteWorkRepository.open(at: database, access: .appReadWrite)
        var last: WorkTask?
        for index in 0..<505 {
            let task = WorkTask(title: "Fixture \(index)", sortOrder: Int64(index))
            _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
            last = task
        }
        let app = AppModel(storeURL: database, legacyURL: root.appending(path: "absent.json"), folderPaths: [])
        await app.load()
        #expect(app.snapshot.tasks.count == 505)
        #expect(app.snapshot.tasks.contains { $0.id == last?.id })
    }

    @Test func failedCheckpointRegistrationRetriesWithoutAppendingTwice() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "context.md")
        try "# Context".write(to: file, atomically: true, encoding: .utf8)
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let fault = RegistrationFaultRepository(base: repository)
        let notes = NotesModel(folders: [root])
        let coordinator = LinkedWorkCoordinator(notes: notes)
        try await coordinator.start(repository: fault)
        await notes.open(file)
        let entry = JournalEntry(sequence: 1, taskID: UUID(), sourceKey: "fixture", occurredAt: .now,
            receivedAt: .now, kind: .response, text: "Unique checkpoint", attribution: .userSelected)
        await coordinator.previewCheckpoint(entry)
        #expect(coordinator.checkpointProposal != nil)
        await fault.failNextRegistration()
        await coordinator.confirmCheckpoint()
        #expect(coordinator.checkpointProposal != nil)
        let written = try Data(contentsOf: file)
        coordinator.cancelCheckpoint()
        #expect(coordinator.checkpointProposal != nil)
        await coordinator.confirmCheckpoint()
        #expect(coordinator.checkpointProposal == nil)
        #expect(try Data(contentsOf: file) == written)
        #expect(notes.body.components(separatedBy: "Unique checkpoint").count == 2)
    }

    @Test func duplicateCreateAndSheetNavigationKeepOneTask() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let coordinator = LinkedWorkCoordinator(notes: NotesModel(folders: []))
        try await coordinator.start(repository: repository)
        let chat = ChatReference(identity: ChatIdentity(hostID: try await repository.info().hostID,
            provider: .codex, sessionID: "fixture-session"), title: "Fixture chat", directory: root.path)
        coordinator.route(.createTaskFromChat(chat))
        async let first: Void = coordinator.createAndAttach()
        async let second: Void = coordinator.createAndAttach()
        _ = await (first, second)
        let tasks = try await repository.tasks(TaskQuery())
        #expect(tasks.items.count == 1)
        let task = try #require(tasks.items.first)
        #expect(try await repository.detail(task.id).chats.map(\.identity) == [chat.identity])
        #expect(coordinator.selectedTask == nil)
        coordinator.resumeNavigation()
        #expect(coordinator.selectedTask == task.id)
        coordinator.selectedTask = nil
        coordinator.connectionNote = UUID()
        coordinator.route(.task(task.id))
        #expect(coordinator.connectionNote == nil)
        #expect(coordinator.selectedTask == nil)
        coordinator.resumeNavigation()
        #expect(coordinator.selectedTask == task.id)
    }

    @Test func renameKeepsIdentityBacklinksAndRejectsExistingFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "context.md"), occupied = root.appending(path: "occupied.md")
        try "Context bytes".write(to: file, atomically: true, encoding: .utf8)
        try "Unrelated bytes".write(to: occupied, atomically: true, encoding: .utf8)
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let notes = NotesModel(folders: [root])
        let coordinator = LinkedWorkCoordinator(notes: notes)
        try await coordinator.start(repository: repository)
        await notes.open(file)
        let reference = try await coordinator.registerNote(file)
        let task = WorkTask(title: "Fixture")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        _ = try await repository.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: reference.id, role: .plan)))
        await coordinator.renameNote(file, name: "renamed.md")
        let renamed = root.appending(path: "renamed.md")
        #expect(notes.selected == renamed)
        #expect(try await repository.note(reference.id).relativePath == "renamed.md")
        #expect(try await repository.detail(task.id).notes.map(\.id) == [reference.id])
        #expect(try String(contentsOf: renamed, encoding: .utf8) == "Context bytes")
        await coordinator.renameNote(renamed, name: "occupied.md")
        #expect(try String(contentsOf: occupied, encoding: .utf8) == "Unrelated bytes")
        #expect(try await repository.note(reference.id).relativePath == "renamed.md")
        #expect(coordinator.error != nil)
    }

}

private actor RegistrationFaultRepository: WorkRepository {
    let base: any WorkRepository
    private var failRegistration = false
    init(base: any WorkRepository) { self.base = base }
    func failNextRegistration() { failRegistration = true }
    func apply(_ mutation: WorkMutation) async throws -> MutationReceipt {
        if case .registerNote = mutation.change, failRegistration {
            failRegistration = false; throw WorkStoreError.busy
        }
        return try await base.apply(mutation)
    }
    func info() async throws -> WorkStoreInfo { try await base.info() }
    func tasks(_ query: TaskQuery) async throws -> WorkPage<WorkTask> { try await base.tasks(query) }
    func detail(_ id: UUID) async throws -> TaskDetail { try await base.detail(id) }
    func folders() async throws -> [FolderReference] { try await base.folders() }
    func note(_ id: UUID) async throws -> NoteReference { try await base.note(id) }
    func notes(_ query: NoteQuery) async throws -> WorkPage<NoteReference> { try await base.notes(query) }
    func connections(_ entity: LinkedEntityID, limit: Int) async throws -> WorkConnections { try await base.connections(entity, limit: limit) }
    func journal(_ query: JournalQuery) async throws -> WorkPage<JournalEntry> { try await base.journal(query) }
    func graph(_ query: GraphQuery) async throws -> GraphSnapshot { try await base.graph(query) }
    func attribution(chats: [ChatIdentity], eventIDs: [UUID]) async throws -> AttributionSnapshot { try await base.attribution(chats: chats, eventIDs: eventIDs) }
    func notchPreferences() async throws -> NotchPreferences { try await base.notchPreferences() }
    func appendJournal(_ batch: JournalBatch) async throws -> JournalReceipt { try await base.appendJournal(batch) }
}
