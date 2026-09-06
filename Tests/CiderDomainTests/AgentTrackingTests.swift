import Foundation
import Testing
@testable import CiderDomain
import CiderData

struct AgentTrackingTests {
    func event(_ name: String, turn: String = "t1", child: String? = nil, time: Double = 1) throws -> AgentEvent {
        var json = ["session_id":"session", "hook_event_name":name, "turn_id":turn, "cwd":"/example/project", "prompt":"PRIVATE", "tool_input":"PRIVATE"]
        if let child { json["agent_id"] = child }
        return try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: json), time: Date(timeIntervalSince1970: time))
    }
    @Test func metadataOnly() throws {
        let encoded = String(decoding: try JSONEncoder().encode(event("SessionStart")), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE")); #expect(!encoded.contains("prompt"))
    }
    @Test func turnAndChildIsolation() throws {
        var ledger = AgentLedger()
        let first = try event("UserPromptSubmit")
        ledger.apply(first); ledger.apply(first)
        #expect(ledger.sessions[first.key]?.history.count == 1)
        ledger.apply(try event("UserPromptSubmit", turn: "t2", time: 2))
        ledger.apply(try event("Stop", turn: "t1", time: 3))
        #expect(ledger.sessions[first.key]?.execution == .working)
        ledger.apply(try event("SubagentStop", turn: "t2", child: "child", time: 4))
        #expect(ledger.sessions[first.key]?.execution == .working)
        #expect(ledger.sessions.count == 2)
    }
    @Test func stopIsNotVerification() throws {
        var ledger = AgentLedger(); ledger.apply(try event("PermissionRequest")); ledger.apply(try event("Stop", time: 2))
        #expect(ledger.sessions.values.first?.execution == .stopped)
        #expect(ledger.sessions.values.first?.attention == nil)
        #expect(ledger.sessions.values.first?.stale(at: Date(timeIntervalSince1970: 400)) == true)
    }
    @Test func mergeRemoveConflict() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appending(path: "settings.json"), helper = root.appending(path: "helper"), bundled = root.appending(path: "bundled")
        try Data("binary".utf8).write(to: bundled)
        let original = Data(#"{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"existing"}]}]}}"#.utf8)
        try original.write(to: config)
        let proposal = try AgentHookSetup.propose(provider: .claude, destination: config, helper: helper, removing: false)
        try AgentHookSetup.apply(proposal, bundledHelper: bundled)
        let installed = try Data(contentsOf: config)
        let second = try AgentHookSetup.propose(provider: .claude, destination: config, helper: helper, removing: false)
        try AgentHookSetup.apply(second, bundledHelper: bundled)
        #expect(try Data(contentsOf: config) == installed)
        let removal = try AgentHookSetup.propose(provider: .claude, destination: config, helper: helper, removing: true)
        try AgentHookSetup.apply(removal, bundledHelper: bundled)
        let result = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as! NSDictionary
        #expect(result == (try JSONSerialization.jsonObject(with: original) as! NSDictionary))
        let stale = try AgentHookSetup.propose(provider: .claude, destination: config, helper: helper, removing: false)
        try Data("{}".utf8).write(to: config)
        #expect(throws: (any Error).self) { try AgentHookSetup.apply(stale, bundledHelper: bundled) }
        #expect(try Data(contentsOf: config) == Data("{}".utf8))
    }
    @Test func spoolReplay() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let spool = root.appending(path: "spool")
        try FileManager.default.createDirectory(at: spool, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let e = try event("UserPromptSubmit", time: Date.now.timeIntervalSince1970)
        let file = spool.appending(path: "event.json")
        try JSONEncoder().encode(e).write(to: file)
        #expect(try AgentEventStore.ingest(root: root).sessions.count == 1)
        try JSONEncoder().encode(e).write(to: file)
        #expect(try AgentEventStore.ingest(root: root).sessions[e.key]?.history.count == 1)
    }
}

@Test func responsePreviewIsBoundedAndOnlyFromCompletion() throws {
    let payload: [String: Any] = ["session_id": "preview", "hook_event_name": "Stop", "last_assistant_message": String(repeating: "a", count: 1000), "prompt": "excluded"]
    let completion = try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: payload))
    #expect(completion.lastMessage?.count == 600)
    var other = payload; other["hook_event_name"] = "PreToolUse"
    #expect(try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: other)).lastMessage == nil)
}
