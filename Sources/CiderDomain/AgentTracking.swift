import Foundation

public enum TrackedProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case codex, claude
    public var id: String { rawValue }
    public var title: String { self == .codex ? "Codex" : "Claude Code" }
    public var events: [String] {
        let common = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SubagentStart", "SubagentStop"]
        return common + (self == .codex ? ["Interrupt"] : ["Notification", "PostToolUseFailure", "StopFailure"])
    }
}
public struct AgentEvent: Codable, Identifiable, Sendable {
    public var schemaVersion = 1
    public let id: UUID
    public let provider: TrackedProvider
    public let session: String
    public let turn: String?
    public let child: String?
    public let name: String
    public let directory: String
    public let tool: String?
    public let notification: String?
    public let toolCallID: String?
    public let questions: [AgentQuestion]?
    public let answeredQuestionIDs: [String]?
    public var origin: AgentOrigin?
    public let lastMessage: String?
    public let time: Date
    public init(provider: TrackedProvider, payload: Data, time: Date = .now) throws {
        guard payload.count <= 1_048_576,
              let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let session = object["session_id"] as? String, !session.isEmpty, session.count < 256,
              let event = object["hook_event_name"] as? String, provider.events.contains(event) else { throw CocoaError(.coderInvalidValue) }
        func field(_ name: String, limit: Int = 256, keepLines: Bool = false) -> String? {
            guard let value = object[name] as? String else { return nil }
            return String(String(value.prefix(limit)).unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || (keepLines && ($0 == "\n" || $0 == "\t")) })
        }
        id = UUID(); self.provider = provider; self.session = field("session_id") ?? session
        turn = field("turn_id"); child = field("agent_id"); name = event
        directory = field("cwd", limit: 2048) ?? ""; tool = field("tool_name")
        notification = field("notification_type"); self.time = time
        toolCallID = field("tool_use_id")
        questions = event == "PreToolUse" ? AgentQuestionInput.questions(provider: provider, tool: tool, requestID: toolCallID, input: object["tool_input"]) : nil
        answeredQuestionIDs = event == "UserPromptSubmit" ? AgentQuestionInput.answeredIDs(prompt: object["prompt"]) : nil
        lastMessage = ["Stop", "SubagentStop"].contains(event) ? field("last_assistant_message", limit: 600, keepLines: true) : nil
    }
    public var sessionKey: String { provider.rawValue + ":" + session }
    public var key: String { sessionKey + (child.map { ":child:" + $0 } ?? "") }
}
public enum AgentExecution: String, Codable, Sendable { case ready = "Ready", working = "Working", stopped = "Finished responding", interrupted = "Interrupted", ended = "Ended", unknown = "Unknown" }
public struct TrackedSession: Codable, Identifiable, Sendable {
    public let id: String
    public let provider: TrackedProvider
    public let session: String
    public let parent: String?
    public var turn: String?
    public var directory: String
    public var title: String?
    public var execution: AgentExecution = .unknown
    public var attention: String?
    public var pendingQuestions: [AgentQuestion]?
    public var lastEvent: String
    public var updated: Date
    public var history: [AgentEvent] = []
    public func stale(at now: Date) -> Bool { now.timeIntervalSince(updated) > 300 }
    public var project: String { directory.isEmpty ? "Unassigned workspace" : URL(fileURLWithPath: directory).lastPathComponent }
    public var displayTitle: String { title ?? project }
}
public struct AgentLedger: Codable, Sendable {
    public var sessions: [String: TrackedSession] = [:]
    public var seen: [UUID] = []
    public init() {}
    public mutating func apply(_ event: AgentEvent) {
        guard event.schemaVersion == 1, !seen.contains(event.id) else { return }
        seen.append(event.id); if seen.count > 4096 { seen.removeFirst(seen.count - 4096) }
        var row = sessions[event.key] ?? TrackedSession(id: event.key, provider: event.provider, session: event.session, parent: event.child == nil ? nil : event.sessionKey, directory: event.directory, lastEvent: event.name, updated: event.time)
        guard event.time >= row.updated else { return }
        // A late terminal event from an older identified turn cannot stop a new turn.
        if let old = row.turn, let incoming = event.turn, old != incoming,
           !(["UserPromptSubmit", "SessionStart", "SubagentStart"].contains(event.name)) { return }
        row.updated = event.time; row.lastEvent = event.name
        if !event.directory.isEmpty { row.directory = event.directory }
        if let turn = event.turn { row.turn = turn }
        switch event.name {
        case "SessionStart": row.execution = .ready; row.attention = nil
        case "UserPromptSubmit", "SubagentStart": row.execution = .working; row.attention = nil
        case "PreToolUse": row.execution = .working
        case "PostToolUse": row.execution = .working // Permission resolution is not reliably correlated.
        case "PermissionRequest": row.attention = "Approval requested"
        case "Notification":
            if event.notification == "permission_prompt" { row.attention = "Approval requested" }
            else if event.notification == "idle_prompt" || event.notification == "elicitation_dialog" { row.attention = "Input requested" }
        case "Stop", "SubagentStop": row.execution = .stopped; row.attention = nil
        case "Interrupt": row.execution = .interrupted; row.attention = nil
        case "SessionEnd": row.execution = .ended; row.attention = nil
        case "StopFailure": row.execution = .unknown; row.attention = "Response error"
        default: break
        }
        if let incoming = event.questions {
            let existing = row.questions.filter { old in !incoming.contains(where: { $0.id == old.id }) }
            row.pendingQuestions = Array((existing + incoming).suffix(12))
        }
        if event.name == "PostToolUse", let requestID = event.toolCallID {
            // Async PostToolUse acknowledges delivery, not a human answer.
            row.pendingQuestions = row.questions.filter { $0.asynchronous || $0.requestID != requestID }
        }
        if event.name == "UserPromptSubmit" {
            if let answered = event.answeredQuestionIDs {
                row.pendingQuestions = row.questions.filter { !answered.contains($0.id) }
            } else { row.pendingQuestions = nil } // A new ordinary prompt supersedes old questions.
        }
        if event.name == "SessionEnd" { row.pendingQuestions = nil }
        row.history.append(event); row.history = Array(row.history.suffix(30))
        sessions[event.key] = row
        if sessions.count > 256, let oldest = sessions.values.min(by: { $0.updated < $1.updated }) { sessions.removeValue(forKey: oldest.id) }
    }
}
