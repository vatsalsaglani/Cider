import Foundation

public enum CiderMascotMood: String, CaseIterable, Sendable {
    case idle, working, needsYou, replyReady
}

/// A short-lived response cue, never a claim that the work has been verified.
public struct CiderMascotReply: Sendable {
    public let eventID: UUID
    public let sessionID: String
    public let receivedAt: Date
    public init?(notice: AgentNotice, receivedAt: Date) {
        guard !notice.requiresInput, notice.session.execution == .stopped,
              let event = notice.session.history.last,
              event.name == "Stop", event.child == nil,
              (0..<20).contains(receivedAt.timeIntervalSince(event.time)) else { return nil }
        eventID = event.id; sessionID = notice.session.id; self.receivedAt = receivedAt
    }
}

public struct CiderMascotState: Equatable, Sendable {
    public let mood: CiderMascotMood
    public let label: String
    public let replyID: UUID?

    public static func resolve(sessions: [TrackedSession], reply: CiderMascotReply? = nil, now: Date) -> Self {
        let active = sessions.filter { $0.execution != .ended }
        // Correlated unanswered questions persist even when the source goes stale.
        // Uncorrelated permission/error notices use the existing freshness policy.
        if active.contains(where: { $0.needsAttention(at: now) }) {
            return Self(mood: .needsYou, label: "An agent needs your attention", replyID: nil)
        }
        if let reply, (0..<5).contains(now.timeIntervalSince(reply.receivedAt)),
           active.contains(where: { $0.id == reply.sessionID && $0.execution == .stopped
               && $0.history.last?.id == reply.eventID && !$0.stale(at: now) }) {
            return Self(mood: .replyReady, label: "An agent finished responding", replyID: reply.eventID)
        }
        if active.contains(where: { $0.execution == .working && !$0.stale(at: now) && $0.updated <= now }) {
            return Self(mood: .working, label: "Agents are working", replyID: nil)
        }
        let unknown = active.contains { $0.stale(at: now) || $0.execution == .unknown || $0.updated > now }
        return Self(mood: .idle, label: unknown ? "Agent activity is not current" : "No agents currently working", replyID: nil)
    }
}
