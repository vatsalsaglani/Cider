import Foundation

public enum NoteRole: String, Codable, CaseIterable, Sendable {
    case plan = "plan"
    case context = "context"
    case evidence = "evidence"
}

public struct FolderReference: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var path: String
    public var available: Bool
    public init(id: UUID = UUID(), path: String, available: Bool = true) {
        self.id = id
        self.path = path
        self.available = available
    }
}

public struct NoteReference: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var rootID: UUID
    public var relativePath: String
    public var fileIdentity: Data?
    public var available: Bool
    public var modifiedAt: Date?
    public init(
        id: UUID = UUID(),
        rootID: UUID,
        relativePath: String,
        fileIdentity: Data? = nil,
        available: Bool = true,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.rootID = rootID
        self.relativePath = relativePath
        self.fileIdentity = fileIdentity
        self.available = available
        self.modifiedAt = modifiedAt
    }
}

public struct NoteFileSnapshot: Codable, Sendable, Equatable {
    public var noteID: UUID
    public var markdown: String
    public var sha256: String
    public var modifiedAt: Date
    public var truncated: Bool
    public init(noteID: UUID, markdown: String, sha256: String, modifiedAt: Date, truncated: Bool = false) {
        self.noteID = noteID
        self.markdown = markdown
        self.sha256 = sha256
        self.modifiedAt = modifiedAt
        self.truncated = truncated
    }
}

public struct NoteDocumentLink: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var sourceID: UUID
    public var targetID: UUID
    public var fragment: String?
    public init(id: UUID = UUID(), sourceID: UUID, targetID: UUID, fragment: String? = nil) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.fragment = fragment
    }
}
