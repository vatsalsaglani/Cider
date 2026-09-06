import Foundation
import CiderDomain

public enum LinkedRoute: Sendable {
    case task(UUID), note(UUID), chat(ChatIdentity), graph(LinkedEntityID?)
    case attachChat(ChatReference), attachNote(UUID)
    case chooseNotes(taskID: UUID), createLinkedNote(taskID: UUID)
    case createTaskFromChat(ChatReference), createTaskFromNote(noteID: UUID, excerpt: String?)
    case saveCheckpoint(JournalEntry), copyContext(taskID: UUID, includeNotes: Bool)
}
