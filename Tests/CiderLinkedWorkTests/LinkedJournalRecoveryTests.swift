import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite struct LinkedJournalRecoveryTests {
    @Test func journalCommitPrecedesLedgerAndSpoolAcknowledgement() async throws {
        let root = try recoveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let spool = root.appending(path: "spool")
        try FileManager.default.createDirectory(at: spool, withIntermediateDirectories: true)
        let event = try completion(time: Date.now)
        let file = spool.appending(path: "completion.json")
        try JSONEncoder().encode(event).write(to: file)

        let batch = try AgentEventStore.readBatch(root: root)
        // A pre-commit failure deliberately does not call acknowledge.
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "sessions.json").path))

        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let task = WorkTask(title: "Recovery")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: event.session), directory: "/synthetic")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: event.turn)))
        let failing = FailingAppendRepository(base: repository)
        await #expect(throws: WorkStoreError.busy) {
            try await JournalIngestor(repository: failing).ingest(events: batch.events, hostID: host, receivedAt: .now)
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try await repository.journal(JournalQuery(taskID: task.id)).items.isEmpty)
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: batch.events, hostID: host, receivedAt: .now)

        // Simulate a crash after the journal transaction, before ledger save.
        let replay = try AgentEventStore.readBatch(root: root)
        _ = try await ingestor.ingest(events: replay.events, hostID: host, receivedAt: .now)
        #expect(try await repository.journal(JournalQuery(taskID: task.id)).items.count == 1)

        // A failed remove is visible and leaves the record for the same safe replay.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: spool.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: spool.path) }
        #expect(throws: (any Error).self) { try AgentEventStore.acknowledge(replay) }
        #expect(FileManager.default.fileExists(atPath: file.path))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: spool.path)
        let final = try AgentEventStore.readBatch(root: root)
        _ = try await ingestor.ingest(events: final.events, hostID: host, receivedAt: .now)
        try AgentEventStore.acknowledge(final)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(try await repository.journal(JournalQuery(taskID: task.id)).items.count == 1)
    }

    @Test func absentTurnDoesNotGuessAcrossMultipleEpisodes() async throws {
        let root = try recoveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let task = WorkTask(title: "No guessed chronology")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "no-turn"), directory: "/synthetic")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        let time = Date.now.addingTimeInterval(1)
        let first = try generic("UserPromptSubmit", session: "no-turn", turn: nil, time: time)
        let second = try generic("UserPromptSubmit", session: "no-turn", turn: nil, time: time.addingTimeInterval(1))
        let stop = try generic("Stop", session: "no-turn", turn: nil, message: "ambiguous", time: time.addingTimeInterval(2))
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: [first, second, stop], hostID: host, receivedAt: time.addingTimeInterval(3))
        #expect(try await repository.journal(JournalQuery(taskID: task.id)).items.isEmpty)
    }

    @Test func ordinaryPromptStopDoesNotScanLargeJournalWithoutReplyIDs() async throws {
        let root = try recoveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let task = WorkTask(title: "Large retained journal")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "large"), directory: "/synthetic")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        let now = Date.now
        let seed = (0..<WorkLimits.attributionRows).map { index in
            JournalDraft(taskID: task.id, sourceKey: "seed-\(index)", occurredAt: now, receivedAt: now, kind: .userNote, text: "x", previewOnly: false, attribution: .userSelected)
        }
        _ = try await repository.appendJournal(JournalBatch(expectedRevision: try await repository.info().revision, entries: seed, episodes: [], processedEventIDs: []))
        let extra = JournalDraft(taskID: task.id, sourceKey: "seed-extra", occurredAt: now, receivedAt: now, kind: .userNote, text: "x", previewOnly: false, attribution: .userSelected)
        _ = try await repository.appendJournal(JournalBatch(expectedRevision: try await repository.info().revision, entries: [extra], episodes: [], processedEventIDs: []))
        let prompt = try generic("UserPromptSubmit", session: "large", turn: "ordinary", time: now.addingTimeInterval(1))
        let stop = try generic("Stop", session: "large", turn: "ordinary", message: "still captured", time: now.addingTimeInterval(2))
        _ = try await JournalIngestor(repository: repository).ingest(events: [prompt, stop], hostID: host, receivedAt: now.addingTimeInterval(3))
        #expect(try await repository.journal(JournalQuery(taskID: task.id, afterSequence: Int64(WorkLimits.attributionRows))).items.contains { $0.text == "still captured" })
    }

    private func recoveryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-journal-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func completion(time: Date) throws -> AgentEvent {
        try generic("Stop", session: "recover", turn: "turn", message: "saved first", time: time)
    }
    private func generic(_ name: String, session: String, turn: String?, message: String? = nil, time: Date) throws -> AgentEvent {
        var payload: [String: String] = ["session_id": session, "hook_event_name": name, "cwd": "/synthetic"]
        if let turn { payload["turn_id"] = turn }; if let message { payload["last_assistant_message"] = message }
        return try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: payload), time: time)
    }
}

private actor FailingAppendRepository: WorkRepository {
    let base: any WorkRepository
    private var failNext = true
    init(base: any WorkRepository) { self.base = base }
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
    func apply(_ mutation: WorkMutation) async throws -> MutationReceipt { try await base.apply(mutation) }
    func appendJournal(_ batch: JournalBatch) async throws -> JournalReceipt {
        if failNext { failNext = false; throw WorkStoreError.busy }
        return try await base.appendJournal(batch)
    }
}
