import Foundation

public struct TaskChatLink: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var taskID: UUID
    public var chat: ChatIdentity
    public var role: String?
    public var startedAt: Date
    public var endedAt: Date?
    public var initialTurnID: String?
    public var revision: Int64
    public init(
        id: UUID = UUID(),
        taskID: UUID,
        chat: ChatIdentity,
        role: String? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        initialTurnID: String? = nil,
        revision: Int64 = 0
    ) {
        self.id = id
        self.taskID = taskID
        self.chat = chat
        self.role = role
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.initialTurnID = initialTurnID
        self.revision = revision
    }
}

public struct TaskNoteLink: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var taskID: UUID
    public var noteID: UUID
    public var role: NoteRole
    public var createdAt: Date
    public init(id: UUID = UUID(), taskID: UUID, noteID: UUID, role: NoteRole  = .context, createdAt: Date  = .now) {
        self.id = id
        self.taskID = taskID
        self.noteID = noteID
        self.role = role
        self.createdAt = createdAt
    }
}

public struct AssignmentEpisode: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var linkID: UUID
    public var sourceStartID: UUID
    public var turnID: String?
    public var startedAt: Date
    public var endedAt: Date?
    public init(
        id: UUID = UUID(),
        linkID: UUID,
        sourceStartID: UUID,
        turnID: String? = nil,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.linkID = linkID
        self.sourceStartID = sourceStartID
        self.turnID = turnID
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
