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

    /// Calls the frozen repository validator before exposing a field-level recovery hint.
    public var validationMessage: String? {
        do { _ = try savedTask() }
        catch {
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the task a title before saving." }
            if title.count > 500 { return "Task titles must be 500 characters or fewer." }
            if descriptionMarkdown.utf8.count > 65_536 { return "Descriptions must be 64 KiB or smaller." }
            if criteria.count > 200 { return "A task can have at most 200 criteria." }
            if criteria.contains(where: { $0.text.count > 1_000 }) { return "Each criterion must be 1,000 characters or fewer." }
            return "Review the task details and try again."
        }
        if criteria.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return "Each criterion needs text or should be removed."
        }
        return nil
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

    /// Applies only locally changed fields to a newly read row, preserving unrelated saved edits.
    public func rebased(onto saved: WorkTask) -> TaskDraft {
        var rebased = TaskDraft(task: saved)
        if title != original.title { rebased.title = title }
        if descriptionMarkdown != original.descriptionMarkdown { rebased.descriptionMarkdown = descriptionMarkdown }
        if plannedDay != original.plannedDay { rebased.plannedDay = plannedDay }
        if dueAt != original.dueAt { rebased.dueAt = dueAt }
        if status != original.status { rebased.status = status }
        if criteria != original.criteria { rebased.criteria = criteria }
        return rebased
    }
}

/// A conflict retains both versions until the person chooses how to continue.
public struct TaskDraftConflict: Sendable, Equatable {
    public let local: TaskDraft
    public let saved: WorkTask
    public init(local: TaskDraft, saved: WorkTask) {
        self.local = local
        self.saved = saved
    }
    public var rebasedDraft: TaskDraft { local.rebased(onto: saved) }

    /// The view may remain editable after a failed save. Rebase its newest draft, not the
    /// historical snapshot retained solely for comparison.
    public func rebasedDraft(using latest: TaskDraft) -> TaskDraft {
        guard latest.taskID == saved.id else { return rebasedDraft }
        return latest.rebased(onto: saved)
    }

    /// Bounded, source-only comparison values; nothing here is executable content.
    public func comparison(using latest: TaskDraft) -> [TaskDraftComparison] {
        let savedDraft = TaskDraft(task: saved)
        var rows: [TaskDraftComparison] = []
        func append(_ field: String, _ saved: String, _ local: String) {
            guard saved != local else { return }
            rows.append(TaskDraftComparison(field: field, saved: bounded(saved), local: bounded(local)))
        }
        append("Title", saved.title, latest.title)
        append("Description", saved.descriptionMarkdown, latest.descriptionMarkdown)
        append("Status", saved.status.rawValue, latest.status.rawValue)
        append("Planned day", saved.plannedDay.date().formatted(date: .abbreviated, time: .omitted), latest.plannedDay.date().formatted(date: .abbreviated, time: .omitted))
        append("Due date", saved.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "None", latest.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "None")
        append("Criteria", criteriaText(savedDraft.criteria), criteriaText(latest.criteria))
        return rows
    }

    private func criteriaText(_ criteria: [WorkCriterion]) -> String {
        criteria.map { "\($0.checked ? "[x]" : "[ ]") \($0.text)" }.joined(separator: "\n")
    }
    private func bounded(_ value: String) -> String {
        let limit = 600
        return value.count > limit ? String(value.prefix(limit)) + "…" : value
    }
}

public struct TaskDraftComparison: Sendable, Equatable, Identifiable {
    public let field: String
    public let saved: String
    public let local: String
    public var id: String { field }
    public init(field: String, saved: String, local: String) {
        self.field = field
        self.saved = saved
        self.local = local
    }
}
