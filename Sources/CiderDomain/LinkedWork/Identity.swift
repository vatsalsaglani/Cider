import Foundation

public struct ChatIdentity: Codable, Sendable, Hashable {
    public var hostID: UUID
    public var provider: TrackedProvider
    public var sessionID: String
    public init(hostID: UUID, provider: TrackedProvider, sessionID: String) {
        self.hostID = hostID
        self.provider = provider
        self.sessionID = sessionID
    }
}

public struct ChatReference: Codable, Sendable, Equatable {
    public var identity: ChatIdentity
    public var title: String?
    public var directory: String
    public var origin: AgentOrigin?
    public var observedAt: Date?
    public var currentTurnID: String?
    public var execution: AgentExecution
    public var attention: String?
    public init(
        identity: ChatIdentity,
        title: String? = nil,
        directory: String,
        origin: AgentOrigin? = nil,
        observedAt: Date? = nil,
        currentTurnID: String? = nil,
        execution: AgentExecution  = .unknown,
        attention: String? = nil
    ) {
        self.identity = identity
        self.title = title
        self.directory = directory
        self.origin = origin
        self.observedAt = observedAt
        self.currentTurnID = currentTurnID
        self.execution = execution
        self.attention = attention
    }
}

public enum LinkedEntityKind: String, Codable, CaseIterable, Sendable {
    case task = "task"
    case chat = "chat"
    case note = "note"
}

/// Stable tagged identity. Titles and paths are display metadata, never keys.
public enum LinkedEntityID: Codable, Sendable, Hashable {
    case task(UUID), chat(ChatIdentity), note(UUID)
    private enum CodingKeys: String, CodingKey { case kind, id, chat }
    public var kind: LinkedEntityKind {
        switch self { case .task: .task; case .chat: .chat; case .note: .note }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(LinkedEntityKind.self, forKey: .kind) {
        case .task: self = .task(try c.decode(UUID.self, forKey: .id))
        case .note: self = .note(try c.decode(UUID.self, forKey: .id))
        case .chat: self = .chat(try c.decode(ChatIdentity.self, forKey: .chat))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch self {
        case .task(let id), .note(let id): try c.encode(id.uuidString.lowercased(), forKey: .id)
        case .chat(let chat): try c.encode(chat, forKey: .chat)
        }
    }
}
