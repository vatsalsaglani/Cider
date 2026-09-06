import Foundation
import CiderDomain

/// User-owned detail edits. Incoming chat metadata never replaces this value.
public struct TaskDraft: Sendable, Equatable {
    public let taskID: UUID
    public let originalRevision: Int64
    private let original: WorkTask
    public var title: String
    public var descriptionMarkdown: String
    public var plannedDay: LocalDay
    public var dueAt: Date?
    public var status: WorkTaskStatus
    public var criteria: [WorkCriterion]

    public init(task: WorkTask) {
        taskID = task.id
        originalRevision = task.revision
        original = task
        title = task.title
        descriptionMarkdown = task.descriptionMarkdown
        plannedDay = task.plannedDay
        dueAt = task.dueAt
        status = task.status
        criteria = task.criteria
    }

    public var criteriaProgress: Double? {
        guard !criteria.isEmpty else { return nil }
        return Double(criteria.filter(\.checked).count) / Double(criteria.count)
    }

    /// Completion is an explicit human choice. Reopening a completed item makes it planned;
    /// changing another field never normalizes a non-done status.
    public mutating func setCompleted(_ completed: Bool) {
        if completed { status = .done }
        else if status == .done { status = .planned }
    }

    public mutating func addCriterion() {
        criteria.append(WorkCriterion(text: ""))
    }

    public mutating func removeCriterion(id: UUID) {
        criteria.removeAll { $0.id == id }
    }

    public mutating func setCriterionChecked(_ checked: Bool, id: UUID, at date: Date = .now) {
        guard let index = criteria.firstIndex(where: { $0.id == id }) else { return }
        criteria[index].checked = checked
        criteria[index].updatedAt = date
    }

    public func savedTask() throws -> WorkTask {
        var task = original
        task.title = title
        task.descriptionMarkdown = descriptionMarkdown
        task.plannedDay = plannedDay
        task.dueAt = dueAt
        task.status = status
        task.criteria = criteria
        task.revision = originalRevision
        try WorkLimits.validate(task: task)
        return task
    }

    public func saveMutation() throws -> WorkMutation {
        WorkMutation(change: .saveTask(task: try savedTask()))
    }
}
