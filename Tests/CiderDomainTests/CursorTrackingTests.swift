import Foundation
import Testing
import CiderDomain
import CiderData

@Suite struct CursorTrackingTests {
    private func event(_ name: String, extra: [String: Any] = [:], seconds: Double = 0) throws -> AgentEvent {
        let base: [String: Any] = ["hook_event_name": name, "conversation_id": "cursor-conversation", "generation_id": "turn-1", "workspace_roots": ["/synthetic"], "user_email": "never-retain@example.invalid", "transcript_path": "/do-not-read"]
        return try AgentEvent(provider: .cursor, payload: JSONSerialization.data(withJSONObject: base.merging(extra) { _, new in new }), time: Date(timeIntervalSince1970: 100 + seconds))
    }
    @Test func responsesAndTerminalStatesRemainSeparate() throws {
        var ledger = AgentLedger()
        let start = try event("beforeSubmitPrompt")
        ledger.apply(start)
        let response = try event("afterAgentResponse", extra: ["text": "Finished **work**"], seconds: 1)
        ledger.apply(response)
        #expect(ledger.sessions[start.key]?.execution == .working)
        #expect(AgentNotice.latest(sessions: Array(ledger.sessions.values), known: [start.id], now: response.time) == nil)
        let stop = try event("stop", extra: ["status": "completed"], seconds: 2)
        ledger.apply(stop)
        let row = try #require(ledger.sessions[stop.key])
        #expect(row.execution == .stopped)
        #expect(row.directory == "/synthetic")
        #expect(AgentNotice.latest(sessions: [row], known: [start.id, response.id], now: stop.time)?.message == "Finished **work**")
        let bytes = String(decoding: try JSONEncoder().encode(response), as: UTF8.self)
        #expect(!bytes.contains("never-retain")); #expect(!bytes.contains("do-not-read"))
        #expect(try event("stop", extra: ["status": "aborted"]).name == "Interrupt")
        #expect(try event("stop", extra: ["status": "error"]).name == "StopFailure")
        #expect(throws: (any Error).self) { try event("stop", extra: ["status": "something-new"]) }
        #expect(throws: (any Error).self) { try event("afterAgentThought", extra: ["text": "discarded"]) }
    }
    @Test func childEventsAndOldTurnsCannotStopParent() throws {
        var ledger = AgentLedger()
        let start = try event("beforeSubmitPrompt")
        ledger.apply(start)
        let child = try event("subagentStop", extra: ["agent_id": "child", "status": "completed"], seconds: 1)
        ledger.apply(child)
        #expect(ledger.sessions[start.key]?.execution == .working)
        #expect(ledger.sessions[child.key]?.execution == .stopped)
        #expect(child.session == start.session)
        #expect(throws: (any Error).self) { try event("subagentStop", extra: ["status": "completed"]) }
        ledger.apply(try event("beforeSubmitPrompt", extra: ["generation_id": "turn-2"], seconds: 2))
        ledger.apply(try event("stop", extra: ["status": "completed"], seconds: 3))
        #expect(ledger.sessions[start.key]?.execution == .working)
    }
    @Test func cursorSetupMergesPreservesAndRemovesOnlyCiderEntries() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "hooks.json"), helper = root.appending(path: "helper")
        let bundled = root.appending(path: "bundled")
        try Data("fixture helper".utf8).write(to: bundled)
        try Data(#"{"version":1,"custom":true,"hooks":{"stop":[{"command":"user-hook","timeout":25}],"workspaceOpen":[{"command":"workspace-hook"}]}}"#.utf8).write(to: file)
        let install = try AgentHookSetup.propose(provider: .cursor, destination: file, helper: helper, removing: false)
        #expect(install.preview.contains("afterAgentResponse"))
        try AgentHookSetup.apply(install, bundledHelper: bundled)
        let update = try AgentHookSetup.propose(provider: .cursor, destination: file, helper: helper, removing: false)
        try AgentHookSetup.apply(update, bundledHelper: bundled)
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let hooks = try #require(json["hooks"] as? [String: [[String: Any]]])
        #expect(hooks["stop"]?.count == 2)
        #expect(hooks["stop"]?.last?["hooks"] == nil)
        let removal = try AgentHookSetup.propose(provider: .cursor, destination: file, helper: helper, removing: true)
        try AgentHookSetup.apply(removal, bundledHelper: bundled)
        let remaining = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let kept = try #require(remaining["hooks"] as? [String: [[String: Any]]])
        #expect(kept["stop"]?.count == 1); #expect(kept["workspaceOpen"]?.count == 1)
        #expect(remaining["custom"] as? Bool == true)
        #expect(kept["sessionStart"] == nil)
        #expect(AgentHookSetup.destination(provider: .cursor, home: root, environment: ["CLAUDE_CONFIG_DIR": "/wrong"]).path == root.appending(path: ".cursor/hooks.json").path)
    }
}
