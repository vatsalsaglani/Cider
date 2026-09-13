import Foundation
import Observation
import CiderDomain
import CiderUI

enum TaskDetailSection: String, CaseIterable {
    case overview = "Overview", chats = "Chats", notes = "Notes", timeline = "Timeline"
}

@MainActor @Observable
final class TaskDetailSession {
    var scrollAnchor: String?
    var showActivity = false
    var showChatPicker = false
    var section: TaskDetailSection = .overview
    var draft: TaskDraft?
    var conflict: TaskDraftConflict?
    var operationError: String?
}

/// Kept by the workspace so following a note doesn't discard an unfinished task edit.
@MainActor @Observable
final class TaskDetailSessions {
    @ObservationIgnored private var sessions: [UUID: TaskDetailSession] = [:]
    func session(_ id: UUID) -> TaskDetailSession {
        if let existing = sessions[id] { return existing }
        let created = TaskDetailSession()
        sessions[id] = created
        return created
    }
}
