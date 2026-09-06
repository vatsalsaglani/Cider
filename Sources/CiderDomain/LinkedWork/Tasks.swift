import Foundation

public enum WorkTaskStatus: String, Codable, CaseIterable, Sendable {
    case planned = "planned"
    case inProgress = "inProgress"
    case blocked = "blocked"
    case readyForReview = "readyForReview"
    case done = "done"
}

public struct WorkCriterion: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var text: String
    public var checked: Bool
    public var updatedAt: Date
    public init(id: UUID = UUID(), text: String, checked: Bool = false, updatedAt: Date  = .now) {
        self.id = id
        self.text = text
        self.checked = checked
        self.updatedAt = updatedAt
    }
}

public struct WorkTask: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var descriptionMarkdown: String
    public var plannedDay: LocalDay
    public var dueAt: Date?
    public var status: WorkTaskStatus
    public var criteria: [WorkCriterion]
    public var createdAt: Date
    public var sortOrder: Int64
    public var revision: Int64
    public init(
        id: UUID = UUID(),
        title: String,
        descriptionMarkdown: String = "",
        plannedDay: LocalDay = LocalDay(),
        dueAt: Date? = nil,
        status: WorkTaskStatus  = .planned,
        criteria: [WorkCriterion] = [],
        createdAt: Date  = .now,
        sortOrder: Int64 = 0,
        revision: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.descriptionMarkdown = descriptionMarkdown
        self.plannedDay = plannedDay
        self.dueAt = dueAt
        self.status = status
        self.criteria = criteria
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.revision = revision
    }
    public var legacyItem: TaskItem {
        TaskItem(id: id, title: title, plannedDay: plannedDay, completed: status == .done, createdAt: createdAt)
    }
    /// Called only for an explicit checkbox action, never an observer update.
    public mutating func toggleCompletion() { status = status == .done ? .planned : .done }
}
