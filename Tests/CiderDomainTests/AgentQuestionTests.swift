import Foundation
import Testing
@testable import CiderDomain

struct AgentQuestionTests {
    func event(_ name: String, tool: String = "request_user_input_async", call: String = "call_1", at: Double = 1,
               provider: TrackedProvider = .codex, extras: [String: Any] = [:]) throws -> AgentEvent {
        var payload: [String: Any] = ["session_id": "question-test", "hook_event_name": name, "tool_name": tool,
                                      "tool_use_id": call, "cwd": "/example", "turn_id": "turn_1",
                                      "tool_input": ["questions": [["title": "Which **folder**?", "question": "Which **folder**?", "options": ["PRIVATE OPTION"]]], "secret": "PRIVATE INPUT"]]
        payload.merge(extras) { _, new in new }
        return try AgentEvent(provider: provider, payload: JSONSerialization.data(withJSONObject: payload), time: Date(timeIntervalSince1970: at))
    }

    func reply(_ calls: [(String, Int)]) throws -> String {
        let rows = try calls.map { call, index in
            ["questionItemId": String(decoding: try JSONSerialization.data(withJSONObject: ["request_user_input_async", call, index]), as: UTF8.self), "answer": "PRIVATE ANSWER"]
        }
        return "<send_user_message_question_reply>\n" + String(decoding: try JSONSerialization.data(withJSONObject: rows), as: UTF8.self) + "\n</send_user_message_question_reply>"
    }

    @Test func asyncDeliveryAndFurtherWorkDoNotAnswerQuestion() throws {
        var ledger = AgentLedger()
        ledger.apply(try event("PreToolUse"))
        ledger.apply(try event("PostToolUse", at: 2, extras: ["tool_response": ["accepted": true]]))
        ledger.apply(try event("PreToolUse", tool: "Bash", at: 3))
        ledger.apply(try event("Stop", at: 4))
        let row = try #require(ledger.sessions.values.first)
        #expect(row.execution == .stopped)
        #expect(row.questions.count == 1)
        #expect(row.needsAttention(at: Date(timeIntervalSince1970: 900)))
        #expect(row.activityLabel(at: Date(timeIntervalSince1970: 900)) == "Asking a question")
        let notice = AgentNotice.latest(sessions: [row], known: [], now: Date(timeIntervalSince1970: 5))
        #expect(notice?.requiresInput == true)
        #expect(notice?.message == "Which **folder**?")
    }

    @Test func asyncReplyResolvesOnlyMatchingQuestionsAndDoesNotPersistAnswer() throws {
        var ledger = AgentLedger()
        ledger.apply(try event("PreToolUse"))
        ledger.apply(try event("PreToolUse", call: "call_2", at: 2))
        let answer = try event("UserPromptSubmit", at: 3, extras: ["prompt": reply([("call_1", 0)])])
        ledger.apply(answer)
        #expect(ledger.sessions.values.first?.questions.map(\.id) == ["call_2:0"])
        let encoded = String(decoding: try JSONEncoder().encode(ledger), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE"))
        ledger.apply(try event("UserPromptSubmit", at: 4, extras: ["prompt": reply([("call_2", 0)])]))
        let row = try #require(ledger.sessions.values.first)
        #expect(row.questions.isEmpty)
        #expect(!row.needsAttention(at: Date(timeIntervalSince1970: 4)))
        #expect(AgentNotice.latest(sessions: [row], known: [], now: Date(timeIntervalSince1970: 5)) == nil)
    }

    @Test func blockingCodexAndClaudeQuestionsResolveAtToolReturn() throws {
        for (provider, tool) in [(TrackedProvider.codex, "request_user_input"), (.claude, "AskUserQuestion")] {
            var ledger = AgentLedger()
            ledger.apply(try event("PreToolUse", tool: tool, provider: provider))
            #expect(ledger.sessions.values.first?.questions.count == 1)
            ledger.apply(try event("PostToolUse", tool: "Bash", call: "unrelated", at: 2, provider: provider))
            #expect(ledger.sessions.values.first?.questions.count == 1)
            ledger.apply(try event("PostToolUse", tool: tool, at: 3, provider: provider))
            #expect(ledger.sessions.values.first?.questions.isEmpty == true)
        }
    }

    @Test func questionCollectionIsAllowlistedAndBounded() throws {
        let long: [String: Any] = ["tool_input": ["questions": Array(repeating: ["title": String(repeating: "Q", count: 300)], count: 20)]]
        let request = try event("PreToolUse", extras: long)
        #expect(request.questions?.count == 2)
        #expect(request.questions?.map(\.text).joined().count == 600)
        #expect(try event("PreToolUse", tool: "unrelated.request_user_input_async").questions == nil)
        #expect(try event("PreToolUse", tool: "Bash").questions == nil)
        #expect(try event("PostToolUse").questions == nil)
        #expect(try event("PreToolUse", extras: ["tool_input": "not an object"]).questions == nil)
        #expect(try event("UserPromptSubmit", extras: ["prompt": "<send_user_message_question_reply>bad</send_user_message_question_reply>"]).answeredQuestionIDs == [])
    }

    @Test func duplicateHooksRestartAndNormalPromptLifecycle() throws {
        var ledger = AgentLedger()
        let question = try event("PreToolUse")
        ledger.apply(question); ledger.apply(question)
        ledger.apply(try event("SessionStart", at: 2))
        #expect(ledger.sessions.values.first?.questions.count == 1)
        let restored = try JSONDecoder().decode(AgentLedger.self, from: JSONEncoder().encode(ledger))
        #expect(restored.sessions.values.first?.questions.count == 1)
        #expect(AgentNotice.latest(sessions: Array(restored.sessions.values), known: Set(restored.seen), now: Date(timeIntervalSince1970: 3)) == nil)
        ledger.apply(try event("UserPromptSubmit", at: 3, extras: ["prompt": "New request"]));
        #expect(ledger.sessions.values.first?.questions.isEmpty == true)
        ledger.apply(try event("PreToolUse", at: 4))
        ledger.apply(try event("SessionEnd", at: 5))
        #expect(ledger.sessions.values.first?.questions.isEmpty == true)
    }

    @Test func olderLedgersDecodeWithoutQuestionFields() throws {
        var ledger = AgentLedger(); ledger.apply(try event("Stop"))
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as! [String: Any]
        var sessions = object["sessions"] as! [String: [String: Any]]
        for key in sessions.keys {
            sessions[key]?.removeValue(forKey: "pendingQuestions")
            var history = sessions[key]!["history"] as! [[String: Any]]
            for index in history.indices {
                for field in ["questions", "toolCallID", "answeredQuestionIDs"] { history[index].removeValue(forKey: field) }
            }
            sessions[key]?["history"] = history
        }
        object["sessions"] = sessions
        let restored = try JSONDecoder().decode(AgentLedger.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.sessions.values.first?.execution == .stopped)
        #expect(restored.sessions.values.first?.questions.isEmpty == true)
    }
}
