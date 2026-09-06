import Foundation

public enum JournalKind: String, Codable, CaseIterable, Sendable {
    case response = "response"
    case question = "question"
    case questionResolved = "questionResolved"
    case userNote = "userNote"
}

public enum JournalAttribution: String, Codable, CaseIterable, Sendable {
    case identifiedTurn = "identifiedTurn"
    case observedEpisode = "observedEpisode"
    case userSelected = "userSelected"
}

public struct JournalEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var taskID: UUID
    public var linkID: UUID?
    public var chat: ChatIdentity?
    public var sourceEventID: UUID?
    public var sourceTurnID: String?
    public var questionID: String?
    public var sourceKey: String
    public var occurredAt: Date
    public var receivedAt: Date
    public var kind: JournalKind
    public var text: String
    public var previewOnly: Bool
    public var attribution: JournalAttribution
    public var sequence: Int64
    public init(
        id: UUID = UUID(),
        sequence: Int64,
        taskID: UUID,
        linkID: UUID? = nil,
        chat: ChatIdentity? = nil,
        sourceEventID: UUID? = nil,
        sourceTurnID: String? = nil,
        questionID: String? = nil,
        sourceKey: String,
        occurredAt: Date,
        receivedAt: Date,
        kind: JournalKind,
        text: String,
        previewOnly: Bool = true,
        attribution: JournalAttribution
    ) {
        self.id = id
        self.taskID = taskID
        self.linkID = linkID
        self.chat = chat
        self.sourceEventID = sourceEventID
        self.sourceTurnID = sourceTurnID
        self.questionID = questionID
        self.sourceKey = sourceKey
        self.occurredAt = occurredAt
        self.receivedAt = receivedAt
        self.kind = kind
        self.text = text
        self.previewOnly = previewOnly
        self.attribution = attribution
        self.sequence = sequence
    }
}

public struct JournalDraft: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var taskID: UUID
    public var linkID: UUID?
    public var chat: ChatIdentity?
    public var sourceEventID: UUID?
    public var sourceTurnID: String?
    public var questionID: String?
    public var sourceKey: String
    public var occurredAt: Date
    public var receivedAt: Date
    public var kind: JournalKind
    public var text: String
    public var previewOnly: Bool
    public var attribution: JournalAttribution
    public init(
        id: UUID = UUID(),
        taskID: UUID,
        linkID: UUID? = nil,
        chat: ChatIdentity? = nil,
        sourceEventID: UUID? = nil,
        sourceTurnID: String? = nil,
        questionID: String? = nil,
        sourceKey: String,
        occurredAt: Date,
        receivedAt: Date,
        kind: JournalKind,
        text: String,
        previewOnly: Bool = true,
        attribution: JournalAttribution
    ) {
        self.id = id
        self.taskID = taskID
        self.linkID = linkID
        self.chat = chat
        self.sourceEventID = sourceEventID
        self.sourceTurnID = sourceTurnID
        self.questionID = questionID
        self.sourceKey = sourceKey
        self.occurredAt = occurredAt
        self.receivedAt = receivedAt
        self.kind = kind
        self.text = text
        self.previewOnly = previewOnly
        self.attribution = attribution
    }
}

public struct AttributionSnapshot: Codable, Sendable, Equatable {
    public var revision: Int64
    public var links: [TaskChatLink]
    public var episodes: [AssignmentEpisode]
    public var processedEventIDs: [UUID]
    public init(revision: Int64, links: [TaskChatLink], episodes: [AssignmentEpisode], processedEventIDs: [UUID]) {
        self.revision = revision
        self.links = links
        self.episodes = episodes
        self.processedEventIDs = processedEventIDs
    }
}

public struct JournalBatch: Codable, Sendable, Equatable {
    public var expectedRevision: Int64
    public var entries: [JournalDraft]
    public var episodes: [AssignmentEpisode]
    public var processedEventIDs: [UUID]
    public init(
        expectedRevision: Int64,
        entries: [JournalDraft],
        episodes: [AssignmentEpisode],
        processedEventIDs: [UUID]
    ) {
        self.expectedRevision = expectedRevision
        self.entries = entries
        self.episodes = episodes
        self.processedEventIDs = processedEventIDs
    }
}

public struct JournalReceipt: Codable, Sendable, Equatable {
    public var revision: Int64
    public var inserted: Int
    public var duplicate: Int
    public init(revision: Int64, inserted: Int, duplicate: Int) {
        self.revision = revision
        self.inserted = inserted
        self.duplicate = duplicate
    }
}
