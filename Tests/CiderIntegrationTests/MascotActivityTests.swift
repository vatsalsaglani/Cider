import Foundation
import Testing
import CiderDomain
@testable import CiderApp

@MainActor struct MascotActivityTests {
    func notice(session: String) throws -> AgentNotice {
        let data = try JSONSerialization.data(withJSONObject: ["session_id": session, "hook_event_name": "Stop"])
        var ledger = AgentLedger(); ledger.apply(try AgentEvent(provider: .codex, payload: data))
        return try #require(AgentNotice.latest(sessions: Array(ledger.sessions.values), known: [], now: .now))
    }
    @Test func bounceIsConsumedOnceAcrossViewRemountsAndNewResponses() throws {
        let model = MascotActivityModel()
        model.receive(try notice(session: "one"), at: .now)
        let first = try #require(model.reply?.eventID)
        #expect(model.claimBounce(first))
        #expect(!model.claimBounce(first))
        model.receive(try notice(session: "two"), at: .now)
        let second = try #require(model.reply?.eventID)
        #expect(!model.claimBounce(first))
        #expect(model.claimBounce(second))
        model.stop()
        #expect(model.reply == nil)
        #expect(!model.claimBounce(second))
    }
    @Test func replyExpressionExpiresWithoutAnyNewProviderActivity() async throws {
        let model = MascotActivityModel()
        model.receive(try notice(session: "one"), at: .now)
        #expect(model.reply != nil)
        try await Task.sleep(for: .milliseconds(5_100))
        // Allow the main actor to service a timer that woke in the same scheduler batch.
        for _ in 0..<10 where model.reply != nil { try await Task.sleep(for: .milliseconds(50)) }
        #expect(model.reply == nil)
        model.stop()
    }
}
