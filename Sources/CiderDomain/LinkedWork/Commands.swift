import Foundation

public struct WorkMutation: Codable, Sendable, Equatable {
    public var commandID: UUID
    public var expectedRevision: Int64?
    public var change: WorkChange
    public init(commandID: UUID = UUID(), expectedRevision: Int64? = nil, change: WorkChange) {
        self.commandID = commandID
        self.expectedRevision = expectedRevision
        self.change = change
    }
}

public struct MutationReceipt: Codable, Sendable, Equatable {
    public var revision: Int64
    public var entity: LinkedEntityID?
    public init(revision: Int64, entity: LinkedEntityID? = nil) {
        self.revision = revision
        self.entity = entity
    }
}

public enum WorkChange: Codable, Sendable, Equatable {
    case saveTask(task: WorkTask)
    case deleteTask(taskID: UUID)
    case attachChat(taskID: UUID, chat: ChatReference, role: String?, initialTurnID: String?)
    case observeChats(chats: [ChatReference])
    case detachChat(linkID: UUID)
    case attachNote(taskID: UUID, noteID: UUID, role: NoteRole)
    case detachNote(linkID: UUID)
    case registerFolder(folder: FolderReference)
    case registerNote(note: NoteReference)
    case setFolderAvailable(rootID: UUID, available: Bool)
    case replaceDocumentLinks(sourceNoteID: UUID, links: [NoteDocumentLink])
    case appendUserNote(taskID: UUID, text: String)
    case setNotch(preferences: NotchPreferences)
}
