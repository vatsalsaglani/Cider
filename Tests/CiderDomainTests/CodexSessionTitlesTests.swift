import Foundation
import Testing
import CiderDomain
import CiderData

struct CodexSessionTitlesTests {
    func withIndex(_ text: String, check: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "session_index.jsonl")
        try Data(text.utf8).write(to: file)
        try check(file)
    }

    @Test func sameWorkspaceSessionsKeepExactNamesAndRenames() throws {
        let index = """
        {"id":"first","thread_name":"Improve search","updated_at":"earlier"}
        {"id":"second","thread_name":"Improve search (2)"}
        {"id":"other","thread_name":"Unrelated private chat"}
        {"id":"first","thread_name":"Improve search and filters"}

        """
        try withIndex(index) { file in
            let titles = try CodexSessionTitles.load(index: file, sessions: ["first", "second"])
            #expect(titles == ["first": "Improve search and filters", "second": "Improve search (2)"])
            try Data("{\"id\":\"second\",\"thread_name\":\"Renamed chat\"}\n".utf8).write(to: file)
            #expect(try CodexSessionTitles.load(index: file, sessions: ["second"])["second"] == "Renamed chat")
        }
    }

    @Test func boundedTailSkipsPartialAndMalformedRows() throws {
        let complete = "{\"id\":\"known\",\"thread_name\":\"Current title\"}\n"
        let incomplete = "{\"id\":\"known\",\"thread_name\":\"Incomplete append\"}"
        try withIndex(String(repeating: "x", count: 1000) + "\ninvalid JSON\n" + complete + incomplete) { file in
            let titles = try CodexSessionTitles.load(index: file, sessions: ["known"], byteLimit: 200)
            #expect(titles == ["known": "Current title"])
        }
    }

    @Test func titlesStayBoundedAndDisplayAsPlainLabels() throws {
        let text = "**Name**\n" + String(repeating: "a", count: 400)
        let line = try JSONSerialization.data(withJSONObject: ["id": "known", "thread_name": text]) + Data([0x0a])
        try withIndex(String(decoding: line, as: UTF8.self)) { file in
            let titles = try CodexSessionTitles.load(index: file, sessions: ["known"])
            #expect(titles["known"]?.count == 200)
            #expect(titles["known"]?.contains("\n") == false)
            #expect(titles["known"]?.hasPrefix("**Name** ") == true)
            #expect(try CodexSessionTitles.load(index: file, sessions: ["missing"]).isEmpty)
        }
    }

    @Test func unsafeOrUnavailableIndexDoesNotProvideTitles() throws {
        try withIndex("{\"id\":\"known\",\"thread_name\":\"Title\"}\n") { file in
            let link = file.deletingLastPathComponent().appending(path: "link.jsonl")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            #expect(try CodexSessionTitles.load(index: link, sessions: ["known"]).isEmpty)
            #expect(throws: (any Error).self) { try CodexSessionTitles.load(index: file.appendingPathExtension("missing"), sessions: ["known"]) }
        }
    }

    @Test func missingTitleRetainsWorkspaceFallback() throws {
        var ledger = AgentLedger()
        let payload: [String: Any] = ["session_id": "session", "hook_event_name": "SessionStart", "cwd": "/example/project"]
        ledger.apply(try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: payload)))
        var row = try #require(ledger.sessions.values.first)
        #expect(row.displayTitle == "project")
        row.title = "Named task"
        #expect(row.displayTitle == "Named task")
        #expect(row.project == "project")
        #expect(row.id == "codex:session")
    }
}
