import Foundation

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
public protocol WorkJournalIngesting: Sendable {
    func ingest(events: [AgentEvent], hostID: UUID, receivedAt: Date) async throws -> JournalReceipt
}

public struct WorkStoreInfo: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var revision: Int64
    public var hostID: UUID
    public init(schemaVersion: Int = 1, revision: Int64, hostID: UUID) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.hostID = hostID
    }
}

public struct WorkPage<Element: Codable & Sendable>: Codable, Sendable {
    public var items: [Element]
    public var nextCursor: String?
    public var revision: Int64
    public init(items: [Element], nextCursor: String? = nil, revision: Int64) {
        self.items = items
        self.nextCursor = nextCursor
        self.revision = revision
    }
}

public struct TaskQuery: Codable, Sendable, Equatable {
    public var day: LocalDay?
    public var includeDone: Bool
    public var search: String
    public var cursor: String?
    public var limit: Int
    public init(
        day: LocalDay? = nil,
        includeDone: Bool = true,
        search: String = "",
        cursor: String? = nil,
        limit: Int = 100
    ) {
        self.day = day
        self.includeDone = includeDone
        self.search = search
        self.cursor = cursor
        self.limit = limit
    }
}

public struct NoteQuery: Codable, Sendable, Equatable {
    public var rootID: UUID?
    public var search: String
    public var cursor: String?
    public var limit: Int
    public init(rootID: UUID? = nil, search: String = "", cursor: String? = nil, limit: Int = 100) {
        self.rootID = rootID
        self.search = search
        self.cursor = cursor
        self.limit = limit
    }
}

public struct JournalQuery: Codable, Sendable, Equatable {
    public var taskID: UUID
    public var afterSequence: Int64?
    public var cursor: String?
    public var limit: Int
    public init(taskID: UUID, afterSequence: Int64? = nil, cursor: String? = nil, limit: Int = 100) {
        self.taskID = taskID
        self.afterSequence = afterSequence
        self.cursor = cursor
        self.limit = limit
    }
}

public struct TaskDetail: Codable, Sendable, Equatable {
    public var task: WorkTask
    public var chats: [ChatReference]
    public var chatLinks: [TaskChatLink]
    public var notes: [NoteReference]
    public var noteLinks: [TaskNoteLink]
    public var journalCount: Int64
    public var truncated: Bool
    public var revision: Int64
    public init(
        task: WorkTask,
        chats: [ChatReference],
        chatLinks: [TaskChatLink],
        notes: [NoteReference],
        noteLinks: [TaskNoteLink],
        journalCount: Int64,
        truncated: Bool = false,
        revision: Int64
    ) {
        self.task = task
        self.chats = chats
        self.chatLinks = chatLinks
        self.notes = notes
        self.noteLinks = noteLinks
        self.journalCount = journalCount
        self.truncated = truncated
        self.revision = revision
    }
}

public struct WorkConnections: Codable, Sendable, Equatable {
    public var entity: LinkedEntityID
    public var tasks: [WorkTask]
    public var chats: [ChatReference]
    public var notes: [NoteReference]
    public var edges: [GraphEdge]
    public var truncated: Bool
    public var revision: Int64
    public init(
        entity: LinkedEntityID,
        tasks: [WorkTask],
        chats: [ChatReference],
        notes: [NoteReference],
        edges: [GraphEdge],
        truncated: Bool = false,
        revision: Int64
    ) {
        self.entity = entity
        self.tasks = tasks
        self.chats = chats
        self.notes = notes
        self.edges = edges
        self.truncated = truncated
        self.revision = revision
    }
}

public enum StoreAccess: String, Codable, CaseIterable, Sendable {
    case appReadWrite = "appReadWrite"
    case cliReadOnly = "cliReadOnly"
}

public struct LegacyImport: Codable, Sendable, Equatable {
    public var workspaceURL: URL
    public var folderPaths: [String]
    public init(workspaceURL: URL, folderPaths: [String]) {
        self.workspaceURL = workspaceURL
        self.folderPaths = folderPaths
    }
}

/// Closed error vocabulary: no arbitrary file, note or provider bodies in errors.
public enum WorkStoreError: String, Error, Codable, Sendable, CaseIterable {
    case notFound, conflict, invalidInput, readOnly, unavailable, busy, unsupportedSchema
    case migrationFailed, outsideRoot, fileChanged, outputLimit, notImplemented
    public var code: String { rawValue }
}

/// Limits are checked at API boundaries before allocating or touching storage.
public enum WorkLimits {
    public static let list = 500
    public static let roots = 100
    public static let eventBatch = 2048
    public static let journalBatch = 4096
    public static let attributionRows = 4096
    public static let noteBytes = 65_536
    public static let contextBytes = 262_144
    public static func validate(limit: Int) throws {
        guard (1...list).contains(limit) else { throw WorkStoreError.invalidInput }
    }
    public static func validate(task: WorkTask) throws {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              task.title.count <= 500, task.descriptionMarkdown.utf8.count <= 65_536,
              task.criteria.count <= 200, Set(task.criteria.map(\.id)).count == task.criteria.count,
              task.criteria.allSatisfy({ !$0.text.isEmpty && $0.text.count <= 1000 }),
              task.revision >= 0, task.createdAt.timeIntervalSince1970.isFinite,
              task.dueAt?.timeIntervalSince1970.isFinite != false else { throw WorkStoreError.invalidInput }
    }
    public static func validate(batch: JournalBatch) throws {
        guard batch.expectedRevision >= 0, batch.entries.count <= journalBatch,
              batch.episodes.count <= journalBatch, batch.processedEventIDs.count <= eventBatch else {
            throw WorkStoreError.outputLimit
        }
        guard batch.entries.allSatisfy({ entry in
            entry.occurredAt.timeIntervalSince1970.isFinite && entry.receivedAt.timeIntervalSince1970.isFinite
                && !entry.sourceKey.isEmpty && entry.sourceKey.utf8.count <= 512
                && (entry.kind == .userNote ? entry.text.utf8.count <= 16384 : entry.text.count <= 600)
        }) else { throw WorkStoreError.invalidInput }
    }
    public static func validate(graph: GraphQuery) throws {
        guard (1...1000).contains(graph.nodeLimit), (1...3000).contains(graph.edgeLimit) else {
            throw WorkStoreError.invalidInput
        }
        if case .local(_, let depth) = graph.scope, !(1...2).contains(depth) { throw WorkStoreError.invalidInput }
    }
}
