import Foundation
import CiderDomain

/// Synthetic saved state. Dates use Foundation's default reference-date JSON encoding.
struct LinkedFixture: Codable, Sendable {
    var referenceTime: Date
    var info: WorkStoreInfo
    var tasks: [WorkTask]
    var chats: [ChatReference]
    var folders: [FolderReference]
    var notes: [NoteReference]
    var chatLinks: [TaskChatLink]
    var noteLinks: [TaskNoteLink]
    var documentLinks: [NoteDocumentLink]
    var journal: [JournalEntry]
    var episodes: [AssignmentEpisode]
    var processedEventIDs: [UUID]
    var notch: NotchPreferences
    static func load() throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: Bundle.module.url(forResource: "linked-v1", withExtension: "json", subdirectory: "Fixtures")!))
    }
}

/// UI test double, not a second database implementation. Unsupported graph/journal writes fail explicitly.
actor FixtureRepository: WorkRepository {
    private var state: LinkedFixture
    private var receipts: [UUID: (WorkMutation, MutationReceipt)] = [:]
    private var holdNextRead = false
    private var heldRead: CheckedContinuation<Void, Never>?
    var readIsHeld: Bool { heldRead != nil }
    func holdNextTaskRead() { holdNextRead = true }
    func releaseTaskRead() { heldRead?.resume(); heldRead = nil }
    init(_ state: LinkedFixture) { self.state = state }
    func info() -> WorkStoreInfo { state.info }
    func folders() -> [FolderReference] { state.folders }
    func notchPreferences() -> NotchPreferences { state.notch }
    func note(_ id: UUID) throws -> NoteReference {
        guard let note = state.notes.first(where: { $0.id == id }) else { throw WorkStoreError.notFound }; return note
    }
    func tasks(_ query: TaskQuery) async throws -> WorkPage<WorkTask> {
        var identity = query; identity.cursor = nil
        let rows = state.tasks.filter { (query.day == nil || $0.plannedDay == query.day) && (query.includeDone || $0.status != .done) && (query.search.isEmpty || $0.title.localizedCaseInsensitiveContains(query.search)) }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        let result = try page(rows, limit: query.limit, cursor: query.cursor, key: queryKey(identity))
        if holdNextRead { holdNextRead = false; await withCheckedContinuation { heldRead = $0 } }
        return result
    }
    func notes(_ query: NoteQuery) throws -> WorkPage<NoteReference> {
        var identity = query; identity.cursor = nil
        let rows = state.notes.filter { (query.rootID == nil || $0.rootID == query.rootID) && (query.search.isEmpty || $0.relativePath.localizedCaseInsensitiveContains(query.search)) }.sorted { $0.id.uuidString < $1.id.uuidString }
        return try page(rows, limit: query.limit, cursor: query.cursor, key: queryKey(identity))
    }
    func detail(_ id: UUID) throws -> TaskDetail {
        guard let task = state.tasks.first(where: { $0.id == id }) else { throw WorkStoreError.notFound }
        let chats = state.chatLinks.filter { $0.taskID == id }; let notes = state.noteLinks.filter { $0.taskID == id }
        return TaskDetail(task: task, chats: state.chats.filter { c in chats.contains { $0.chat == c.identity } }, chatLinks: chats, notes: state.notes.filter { n in notes.contains { $0.noteID == n.id } }, noteLinks: notes, journalCount: Int64(state.journal.filter { $0.taskID == id }.count), revision: state.info.revision)
    }
    func journal(_ query: JournalQuery) throws -> WorkPage<JournalEntry> {
        _ = try detail(query.taskID)
        var identity = query; identity.cursor = nil
        let rows = state.journal.filter { $0.taskID == query.taskID && $0.sequence > (query.afterSequence ?? 0) }.sorted { $0.sequence < $1.sequence }
        return try page(rows, limit: query.limit, cursor: query.cursor, key: queryKey(identity))
    }
    func connections(_ entity: LinkedEntityID, limit: Int) throws -> WorkConnections {
        try WorkLimits.validate(limit: limit)
        let taskIDs: Set<UUID>
        switch entity {
        case .task(let id): _ = try detail(id); taskIDs = [id]
        case .note(let id): _ = try note(id); taskIDs = Set(state.noteLinks.filter { $0.noteID == id }.map(\.taskID))
        case .chat(let chat):
            guard state.chats.contains(where: { $0.identity == chat }) else { throw WorkStoreError.notFound }
            taskIDs = Set(state.chatLinks.filter { $0.chat == chat }.map(\.taskID))
        }
        let tasks = state.tasks.filter { taskIDs.contains($0.id) }
        let chatLinks = state.chatLinks.filter { taskIDs.contains($0.taskID) }
        let noteLinks = state.noteLinks.filter { taskIDs.contains($0.taskID) }
        let chats = state.chats.filter { c in chatLinks.contains { $0.chat == c.identity } }
        let notes = state.notes.filter { n in noteLinks.contains { $0.noteID == n.id } }
        let edges = chatLinks.map { GraphEdge(id: $0.id, source: .chat($0.chat), target: .task($0.taskID), kind: .contributes) }
            + noteLinks.map { GraphEdge(id: $0.id, source: .task($0.taskID), target: .note($0.noteID), kind: $0.role == .plan ? .notePlan : $0.role == .evidence ? .noteEvidence : .noteContext) }
        return WorkConnections(entity: entity, tasks: Array(tasks.prefix(limit)), chats: Array(chats.prefix(limit)), notes: Array(notes.prefix(limit)), edges: Array(edges.prefix(limit)), truncated: [tasks.count,chats.count,notes.count,edges.count].contains { $0 > limit }, revision: state.info.revision)
    }
    func graph(_ query: GraphQuery) throws -> GraphSnapshot { throw WorkStoreError.notImplemented }
    func attribution(chats: [ChatIdentity], eventIDs: [UUID]) throws -> AttributionSnapshot {
        guard chats.count <= WorkLimits.list, eventIDs.count <= WorkLimits.eventBatch else { throw WorkStoreError.outputLimit }
        let links = state.chatLinks.filter { chats.contains($0.chat) }
        return AttributionSnapshot(revision: state.info.revision, links: links, episodes: state.episodes.filter { e in links.contains { $0.id == e.linkID } }, processedEventIDs: state.processedEventIDs.filter { eventIDs.contains($0) })
    }
    func appendJournal(_ batch: JournalBatch) throws -> JournalReceipt { throw WorkStoreError.notImplemented }
    func apply(_ mutation: WorkMutation) throws -> MutationReceipt {
        if let (old, receipt) = receipts[mutation.commandID] {
            guard old == mutation else { throw WorkStoreError.conflict }; return receipt
        }
        guard mutation.expectedRevision == nil || mutation.expectedRevision == state.info.revision else { throw WorkStoreError.conflict }
        var entity: LinkedEntityID?
        switch mutation.change {
        case .saveTask(var task):
            try WorkLimits.validate(task: task)
            let index = state.tasks.firstIndex { $0.id == task.id }
            guard task.revision == index.map({ state.tasks[$0].revision }) ?? 0 else { throw WorkStoreError.conflict }
            task.revision += 1
            if let index { state.tasks[index] = task } else { state.tasks.append(task) }; entity = .task(task.id)
        case .attachChat(let taskID, let chat, let role, let initialTurnID):
            _ = try detail(taskID)
            guard role == nil || role!.count <= 120 else { throw WorkStoreError.invalidInput }
            if !state.chats.contains(where: { $0.identity == chat.identity }) { state.chats.append(chat) }
            if !state.chatLinks.contains(where: { $0.taskID == taskID && $0.chat == chat.identity && $0.endedAt == nil }) {
                state.chatLinks.append(TaskChatLink(taskID: taskID, chat: chat.identity, role: role, startedAt: .now, initialTurnID: initialTurnID, revision: 1))
            }; entity = .task(taskID)
        case .detachChat(let id):
            guard let i = state.chatLinks.firstIndex(where: { $0.id == id }) else { throw WorkStoreError.notFound }
            state.chatLinks[i].endedAt = state.chatLinks[i].endedAt ?? .now; state.chatLinks[i].revision += 1
        case .attachNote(let taskID, let noteID, let role):
            _ = try detail(taskID); _ = try note(noteID)
            if let i = state.noteLinks.firstIndex(where: { $0.taskID == taskID && $0.noteID == noteID }) { state.noteLinks[i].role = role }
            else { state.noteLinks.append(TaskNoteLink(taskID: taskID, noteID: noteID, role: role)) }; entity = .task(taskID)
        case .detachNote(let id):
            guard state.noteLinks.contains(where: { $0.id == id }) else { throw WorkStoreError.notFound }
            state.noteLinks.removeAll { $0.id == id }
        case .registerFolder(let folder):
            if let i = state.folders.firstIndex(where: { $0.id == folder.id }) { state.folders[i] = folder }
            else { guard state.folders.count < WorkLimits.roots else { throw WorkStoreError.outputLimit }; state.folders.append(folder) }
        case .registerNote(let note):
            guard state.folders.contains(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
            if let i = state.notes.firstIndex(where: { $0.id == note.id }) { state.notes[i] = note } else { state.notes.append(note) }; entity = .note(note.id)
        case .observeChats(let chats):
            guard chats.count <= WorkLimits.list else { throw WorkStoreError.outputLimit }
            for chat in chats { if let i = state.chats.firstIndex(where: { $0.identity == chat.identity }) { state.chats[i] = chat } }
        case .setFolderAvailable(let id, let available):
            guard let i = state.folders.firstIndex(where: { $0.id == id }) else { throw WorkStoreError.notFound }; state.folders[i].available = available
        case .replaceDocumentLinks(let id, let links):
            _ = try note(id)
            guard links.count <= WorkLimits.list, links.allSatisfy({ $0.sourceID == id }) else { throw WorkStoreError.invalidInput }
            for link in links { _ = try note(link.targetID) }
            state.documentLinks.removeAll { $0.sourceID == id }; state.documentLinks.append(contentsOf: links)
        case .setNotch(let preferences): state.notch = preferences
        case .appendUserNote(let taskID, let text):
            _ = try detail(taskID)
            guard text.utf8.count <= 16384 else { throw WorkStoreError.outputLimit }
            state.journal.append(JournalEntry(sequence: (state.journal.map(\.sequence).max() ?? 0) + 1, taskID: taskID, sourceKey: mutation.commandID.uuidString, occurredAt: .now, receivedAt: .now, kind: .userNote, text: text, previewOnly: false, attribution: .userSelected))
        case .deleteTask(let id):
            _ = try detail(id)
            let linkIDs = Set(state.chatLinks.filter { $0.taskID == id }.map(\.id))
            state.tasks.removeAll { $0.id == id }; state.chatLinks.removeAll { $0.taskID == id }; state.noteLinks.removeAll { $0.taskID == id }
            state.journal.removeAll { $0.taskID == id }; state.episodes.removeAll { linkIDs.contains($0.linkID) }
        }
        state.info.revision += 1
        let receipt = MutationReceipt(revision: state.info.revision, entity: entity)
        receipts[mutation.commandID] = (mutation, receipt); return receipt
    }
    private func queryKey<T: Encodable>(_ query: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys; return try encoder.encode(query)
    }
    private struct Cursor: Codable { var key: Data; var revision: Int64; var offset: Int }
    private func page<T: Codable & Sendable>(_ rows: [T], limit: Int, cursor: String?, key: Data) throws -> WorkPage<T> {
        try WorkLimits.validate(limit: limit)
        var offset = 0
        if let cursor {
            guard cursor.utf8.count < 8192, let data = Data(base64Encoded: cursor), let decoded = try? JSONDecoder().decode(Cursor.self, from: data) else { throw WorkStoreError.invalidInput }
            guard decoded.key == key, decoded.revision == state.info.revision else { throw WorkStoreError.conflict }
            offset = decoded.offset
        }
        guard (0...rows.count).contains(offset) else { throw WorkStoreError.invalidInput }
        let end = min(offset + limit, rows.count)
        let next = end < rows.count ? try JSONEncoder().encode(Cursor(key: key, revision: state.info.revision, offset: end)).base64EncodedString() : nil
        return WorkPage(items: Array(rows[offset..<end]), nextCursor: next, revision: state.info.revision)
    }
}
