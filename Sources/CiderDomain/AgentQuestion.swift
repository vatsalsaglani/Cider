import Foundation

/// An allowlisted question excerpt, never an answer or arbitrary tool input.
public struct AgentQuestion: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let requestID: String
    public let text: String
    public let asynchronous: Bool
}

enum AgentQuestionInput {
    static func kind(provider: TrackedProvider, tool: String?) -> Bool? {
        switch (provider, tool) {
        case (.codex, "request_user_input_async"), (.codex, "functions.request_user_input_async"): true
        case (.codex, "request_user_input"), (.codex, "functions.request_user_input"), (.claude, "AskUserQuestion"): false
        default: nil
        }
    }

    static func questions(provider: TrackedProvider, tool: String?, requestID: String?, input: Any?) -> [AgentQuestion]? {
        guard let asynchronous = kind(provider: provider, tool: tool), let requestID,
              let input = input as? [String: Any], let questions = input["questions"] as? [[String: Any]] else { return nil }
        // At most three questions, 600 characters total, keeping the spool well below 8 KiB.
        var remaining = 600
        let result = questions.prefix(3).enumerated().compactMap { index, question -> AgentQuestion? in
            guard remaining > 0, let text = question[asynchronous ? "title" : "question"] as? String else { return nil }
            let excerpt = String(String(text.prefix(remaining)).unicodeScalars.filter {
                !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t"
            }).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !excerpt.isEmpty else { return nil }
            remaining -= excerpt.count
            return AgentQuestion(id: requestID + ":" + String(index), requestID: requestID, text: excerpt, asynchronous: asynchronous)
        }
        return result.isEmpty ? nil : result
    }

    /// Codex's structured async reply carries the original call ID and question index.
    /// Read only that identity; discard question copies, answers and all surrounding content.
    static func answeredIDs(prompt: Any?) -> [String]? {
        guard let prompt = prompt as? String,
              let start = prompt.range(of: "<send_user_message_question_reply>"),
              let end = prompt.range(of: "</send_user_message_question_reply>", range: start.upperBound..<prompt.endIndex) else { return nil }
        let payload = Data(prompt[start.upperBound..<end.lowerBound].utf8)
        guard let replies = try? JSONSerialization.jsonObject(with: payload) as? [[String: Any]] else { return [] }
        return replies.prefix(12).compactMap { reply in
            guard let encodedID = reply["questionItemId"] as? String, encodedID.utf8.count < 1024,
                  let parts = try? JSONSerialization.jsonObject(with: Data(encodedID.utf8)) as? [Any], parts.count == 3,
                  parts[0] as? String == "request_user_input_async",
                  let callID = parts[1] as? String, !callID.isEmpty, callID.count <= 256,
                  let index = parts[2] as? Int, (0..<3).contains(index) else { return nil }
            return callID + ":" + String(index)
        }
    }
}

extension TrackedSession {
    public var questions: [AgentQuestion] { pendingQuestions ?? [] }
    public var attentionLabel: String? { questions.isEmpty ? attention : "Asking a question" }
    public func needsAttention(at now: Date) -> Bool { !questions.isEmpty || (attention != nil && !stale(at: now)) }
    public func activityLabel(at now: Date) -> String {
        if needsAttention(at: now), let attentionLabel { return attentionLabel }
        return (stale(at: now) ? "Last seen: " : "") + execution.rawValue
    }
}
