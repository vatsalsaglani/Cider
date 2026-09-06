import Foundation

public struct AgentNotice: Sendable {
    public let session: TrackedSession
    public let title: String
    public let message: String
    public let requiresInput: Bool

    public static func latest(sessions: [TrackedSession], known: Set<UUID>, now: Date) -> AgentNotice? {
        let fresh = sessions.flatMap { row in
            row.history.filter { !known.contains($0.id) && (0..<20).contains(now.timeIntervalSince($0.time)) }
                .map { (row, $0) }
        }.sorted { $0.1.time > $1.1.time }
        // An already answered question must not flash when several hooks arrive together.
        for (row, event) in fresh where event.name == "PreToolUse" {
            let pending = (event.questions ?? []).filter { question in row.questions.contains(where: { $0.id == question.id }) }
            if !pending.isEmpty {
                return AgentNotice(session: row, title: row.provider.title + " needs your input", message: pending.map(\.text).joined(separator: "\n"), requiresInput: true)
            }
        }
        for (row, event) in fresh where event.name == "Stop" && event.child == nil && row.questions.isEmpty {
            return AgentNotice(session: row, title: event.provider.title + " finished responding", message: event.lastMessage ?? "Open Agents to see the activity.", requiresInput: false)
        }
        return nil
    }
}
