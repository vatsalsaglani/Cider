import Foundation
import Testing
import CiderDomain
import CiderData
@testable import CiderApp

@Suite @MainActor struct LinkedWorkflowTests {
    @Test func journalContextGraphAndDeletionUseTheSameSavedIdentities() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appending(path: "work.sqlite")
        let file = root.appending(path: "shared.md")
        try Data("# Saved context".utf8).write(to: file)
        let repository = try await SQLiteWorkRepository.open(at: database, access: .appReadWrite)
        let coordinator = LinkedWorkCoordinator(notes: NotesModel(folders: [root]))
        try await coordinator.start(repository: repository)
        let host = try await repository.info().hostID
        let tasks = [WorkTask(title: "First"), WorkTask(title: "Second"), WorkTask(title: "Other chat")]
        for task in tasks { _ = try await repository.apply(WorkMutation(change: .saveTask(task: task))) }
        let first = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "first-chat"), title: "Same title", directory: root.path)
        let second = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "second-chat"), title: "Same title", directory: root.path)
        for (index, task) in tasks.enumerated() {
            _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: index == 2 ? second : first, role: nil, initialTurnID: nil)))
        }
        let note = try await coordinator.registerNote(file)
        for task in tasks.prefix(2) { _ = try await repository.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: note.id, role: .context))) }
        let time = Date.now.addingTimeInterval(1)
        let prompt = try event("UserPromptSubmit", time: time)
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: [prompt], hostID: host, receivedAt: time)
        let link = try #require(try await repository.detail(tasks[0].id).chatLinks.first)
        _ = try await repository.apply(WorkMutation(change: .detachChat(linkID: link.id)))
        let stop = try event("Stop", time: time.addingTimeInterval(1), message: "**Reported result**")
        let trackingRoot = root.appending(path: "Tracking")
        let spool = trackingRoot.appending(path: "spool")
        try FileManager.default.createDirectory(at: spool, withIntermediateDirectories: true)
        let eventFile = spool.appending(path: "stop.json")
        try JSONEncoder().encode(stop).write(to: eventFile)
        let batch = try AgentEventStore.readBatch(root: trackingRoot)
        _ = try await ingestor.ingest(events: batch.events, hostID: host, receivedAt: .now)
        // Crash between journal commit and acknowledgement must be replay-safe.
        let replay = try AgentEventStore.readBatch(root: trackingRoot)
        _ = try await ingestor.ingest(events: replay.events, hostID: host, receivedAt: .now)
        try AgentEventStore.acknowledge(replay)
        #expect(!FileManager.default.fileExists(atPath: eventFile.path))
        let reopened = try await SQLiteWorkRepository.open(at: database, access: .cliReadOnly)
        for task in tasks.prefix(2) {
            #expect(try await reopened.journal(JournalQuery(taskID: task.id)).items.count == 1)
            #expect(try await reopened.detail(task.id).task.status == .planned)
        }
        #expect(try await reopened.journal(JournalQuery(taskID: tasks[2].id)).items.isEmpty)
        let context = try await TodoContextReader(repository: reopened, noteAccess: LinkedNoteService()).context(taskID: tasks[1].id)
        #expect(context.notes.first?.content == nil)
        #expect(context.activity.items.first?.text == "**Reported result**")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let uiContext = try decoder.decode(TodoContextBundle.self, from: try await coordinator.contextData(taskID: tasks[1].id, includeNotes: false))
        #expect(uiContext.detail.task.id == context.detail.task.id)
        let withNotes = try await TodoContextReader(repository: reopened, noteAccess: LinkedNoteService()).context(taskID: tasks[1].id, options: TodoContextOptions(includeNotes: true))
        #expect(withNotes.notes.first?.content == "# Saved context")
        let graph = try await reopened.graph(GraphQuery(includeIsolated: true))
        #expect(graph.nodes.contains { $0.id == .chat(first.identity) })
        #expect(graph.nodes.contains { $0.id == .chat(second.identity) })
        #expect(graph.nodes.contains { $0.id == .note(note.id) })
        #expect(try await reopened.connections(.note(note.id), limit: 100).tasks.count == 2)
        let bytes = try Data(contentsOf: file)
        _ = try await repository.apply(WorkMutation(change: .deleteTask(taskID: tasks[1].id)))
        #expect(try Data(contentsOf: file) == bytes)
        #expect(try await repository.graph(GraphQuery(includeIsolated: true)).nodes.contains { $0.id == .chat(first.identity) })
    }

    @Test func checkpointDestinationAndRetryAcrossRestartDoNotDuplicateBytes() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "destination.md")
        try Data("# Destination".utf8).write(to: file)
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let first = LinkedWorkCoordinator(notes: NotesModel(folders: [root]))
        try await first.start(repository: repository)
        let entry = JournalEntry(sequence: 1, taskID: UUID(), sourceKey: "fixture", occurredAt: .now,
                                 receivedAt: .now, kind: .response, text: "Unique preview", attribution: .userSelected)
        await first.previewCheckpoint(entry, destination: file)
        #expect(first.checkpointProposal != nil)
        await first.confirmCheckpoint()
        let saved = try Data(contentsOf: file)
        let second = LinkedWorkCoordinator(notes: NotesModel(folders: [root]))
        try await second.start(repository: repository)
        await second.previewCheckpoint(entry, destination: file)
        #expect(second.checkpointProposal == nil)
        #expect(second.contextStatus != nil)
        #expect(try Data(contentsOf: file) == saved)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-workflow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func event(_ name: String, time: Date, message: String? = nil) throws -> AgentEvent {
        var payload = ["session_id": "first-chat", "turn_id": "turn-one", "hook_event_name": name, "cwd": "/synthetic"]
        payload["last_assistant_message"] = message
        return try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: payload), time: time)
    }
}
