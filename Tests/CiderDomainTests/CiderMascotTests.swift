import Foundation
import Testing
@testable import CiderDomain

struct CiderMascotTests {
    let now = Date(timeIntervalSince1970: 1_000)
    func event(_ name: String, session: String = "one", at: Date? = nil, provider: TrackedProvider = .codex, extras: [String: Any] = [:]) throws -> AgentEvent {
        var payload: [String: Any] = ["session_id": session, "hook_event_name": name, "turn_id": "turn", "cwd": "/fixture"]
        payload.merge(extras) { _, new in new }
        return try AgentEvent(provider: provider, payload: JSONSerialization.data(withJSONObject: payload), time: at ?? now)
    }
    func state(_ ledger: AgentLedger, reply: CiderMascotReply? = nil, at: Date? = nil) -> CiderMascotState {
        .resolve(sessions: Array(ledger.sessions.values), reply: reply, now: at ?? now)
    }
    func reply(_ ledger: AgentLedger, at: Date? = nil) throws -> CiderMascotReply {
        let notice = try #require(AgentNotice.latest(sessions: Array(ledger.sessions.values), known: [], now: at ?? now))
        return try #require(CiderMascotReply(notice: notice, receivedAt: at ?? now))
    }

    @Test func unresolvedInputOutranksWorkingAndFreshResponsesEvenWhenStale() throws {
        var ledger = AgentLedger()
        ledger.apply(try event("Stop"))
        let cue = try reply(ledger)
        ledger.apply(try event("UserPromptSubmit", session: "two"))
        ledger.apply(try event("PreToolUse", session: "three", extras: [
            "tool_name": "request_user_input_async", "tool_use_id": "ask",
            "tool_input": ["questions": [["title": "Choose a folder"]]]
        ]))
        #expect(state(ledger, reply: cue).mood == .needsYou)
        #expect(state(ledger, reply: cue, at: now.addingTimeInterval(600)).mood == .needsYou)
        ledger.apply(try event("UserPromptSubmit", session: "three", at: now.addingTimeInterval(601)))
        #expect(state(ledger, at: now.addingTimeInterval(601)).mood == .working)
    }

    @Test func happyCueExpiresAndDoesNotRepresentHistoricalCompletion() throws {
        var ledger = AgentLedger(); ledger.apply(try event("Stop"))
        let cue = try reply(ledger)
        #expect(state(ledger).mood == .idle)
        #expect(state(ledger, reply: cue).mood == .replyReady)
        #expect(state(ledger, reply: cue).label == "An agent finished responding")
        #expect(state(ledger, reply: cue, at: now.addingTimeInterval(5)).mood == .idle)
        #expect(state(ledger, reply: cue, at: now.addingTimeInterval(-1)).mood == .idle)
        #expect(AgentNotice.latest(sessions: Array(ledger.sessions.values), known: Set(ledger.seen), now: now) == nil)
        ledger.apply(try event("UserPromptSubmit", at: now.addingTimeInterval(1), extras: ["turn_id": "next"]))
        #expect(state(ledger, reply: cue, at: now.addingTimeInterval(1)).mood == .working)
    }

    @Test func staleUnknownAndEndedSessionsDoNotPretendToBeWorking() throws {
        var ledger = AgentLedger(); ledger.apply(try event("UserPromptSubmit"))
        #expect(state(ledger).mood == .working)
        #expect(state(ledger, at: now.addingTimeInterval(301)).mood == .idle)
        #expect(state(ledger, at: now.addingTimeInterval(301)).label == "Agent activity is not current")
        ledger.apply(try event("PermissionRequest"))
        #expect(state(ledger).mood == .needsYou)
        #expect(state(ledger, at: now.addingTimeInterval(301)).mood == .idle)
        ledger.apply(try event("SessionEnd"))
        #expect(state(ledger).mood == .idle)
        ledger.apply(try event("StopFailure", session: "error", provider: .claude))
        #expect(state(ledger).mood == .needsYou)
        #expect(state(ledger, at: now.addingTimeInterval(301)).mood == .idle)
    }

    @Test func oneWorkingAgentAmongFinishedAgentsKeepsWorkingMood() throws {
        var ledger = AgentLedger()
        ledger.apply(try event("Stop"))
        let cue = try reply(ledger)
        ledger.apply(try event("PreToolUse", session: "two"))
        #expect(state(ledger).mood == .working)
        // A brief response cue may interrupt, but cannot leave the remaining worker idle.
        #expect(state(ledger, reply: cue).mood == .replyReady)
        #expect(state(ledger, reply: cue, at: now.addingTimeInterval(5)).mood == .working)
        ledger.apply(try event("Stop", session: "two", at: now.addingTimeInterval(6)))
        #expect(state(ledger, at: now.addingTimeInterval(6)).mood == .idle)
    }

    @Test func childWorkCountsButChildStopsDoNotCelebrate() throws {
        var ledger = AgentLedger()
        ledger.apply(try event("SubagentStart", extras: ["agent_id": "child"]))
        #expect(state(ledger).mood == .working)
        ledger.apply(try event("SubagentStop", extras: ["agent_id": "child"]))
        #expect(state(ledger).mood == .idle)
        #expect(AgentNotice.latest(sessions: Array(ledger.sessions.values), known: [], now: now) == nil)
    }
}
