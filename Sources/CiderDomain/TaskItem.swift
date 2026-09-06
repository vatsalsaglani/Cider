import Foundation

public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var plannedDay: LocalDay
    public var completed: Bool
    public let createdAt: Date
    public init(id: UUID = UUID(), title: String, plannedDay: LocalDay = LocalDay(), completed: Bool = false, createdAt: Date = .now) {
        self.id = id; self.title = title; self.plannedDay = plannedDay; self.completed = completed; self.createdAt = createdAt
    }
}
