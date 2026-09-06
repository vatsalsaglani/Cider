import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite struct LinkedJournalTests {
    @Test func responsePreviewsFollowEpisodesNotDirectoriesAndReplayPerTask() async throws {
        let root = try journalRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let first = WorkTask(title: "First shared contributor")
        let second = WorkTask(title: "Second shared contributor")
        let unrelated = WorkTask(title: "Different chat")
        for task in [first, second, unrelated] { _ = try await repository.apply(WorkMutation(change: .saveTask(task: task))) }
        let shared = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "shared"), directory: "/same-cwd")
        let other = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "other"), directory: "/same-cwd")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: first.id, chat: shared, role: nil, initialTurnID: nil)))
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: second.id, chat: shared, role: nil, initialTurnID: nil)))
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: unrelated.id, chat: other, role: nil, initialTurnID: nil)))

        let started = Date.now.addingTimeInterval(1)
        let prompt = try event("UserPromptSubmit", session: "shared", turn: "turn-one", time: started)
        let stop = try event("Stop", session: "shared", turn: "turn-one", message: "**Reported** result", time: started.addingTimeInterval(1))
        let ingestor = JournalIngestor(repository: repository)
        #expect(try await ingestor.ingest(events: [prompt, stop], hostID: host, receivedAt: started.addingTimeInterval(2)).inserted == 2)
        #expect(try await repository.journal(JournalQuery(taskID: first.id)).items.map(\.text) == ["**Reported** result"])
        #expect(try await repository.journal(JournalQuery(taskID: second.id)).items.map(\.text) == ["**Reported** result"])
        #expect(try await repository.journal(JournalQuery(taskID: unrelated.id)).items.isEmpty)
        _ = try await ingestor.ingest(events: [prompt, stop], hostID: host, receivedAt: started.addingTimeInterval(3))
        #expect(try await repository.journal(JournalQuery(taskID: first.id)).items.count == 1)
    }

    @Test func delayedStopUsesOriginalEpisodeAfterDetachAndChildNeedsParentSession() async throws {
        let root = try journalRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let task = WorkTask(title: "Detach safely")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "parent"), directory: "/same")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        let start = Date.now.addingTimeInterval(1)
        let prompt = try event("UserPromptSubmit", session: "parent", turn: "old", time: start)
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: [prompt], hostID: host, receivedAt: start)
        let link = try #require(try await repository.detail(task.id).chatLinks.first)
        _ = try await repository.apply(WorkMutation(change: .detachChat(linkID: link.id)))
        let delayed = try event("Stop", session: "parent", turn: "old", message: "late original", time: start.addingTimeInterval(5))
        let child = try event("SubagentStop", session: "parent", turn: "old", child: "child-1", message: "child result", time: start.addingTimeInterval(6))
        let ambiguous = try event("SubagentStop", session: "unlinked-parent", turn: "old", child: "child-1", message: "must stay unassigned", time: start.addingTimeInterval(7))
        _ = try await ingestor.ingest(events: [delayed, child, ambiguous], hostID: host, receivedAt: start.addingTimeInterval(8))
        #expect(try await repository.journal(JournalQuery(taskID: task.id)).items.map(\.text) == ["late original", "child result"])
    }

    @Test func questionResolutionPairsByIDWithPriorEpisodeAcrossNewTurn() async throws {
        let root = try journalRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let task = WorkTask(title: "Question pairing")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "questions"), directory: "/same")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        let start = Date.now.addingTimeInterval(1)
        let prompt = try event("UserPromptSubmit", session: "questions", turn: "one", time: start)
        let question = try event("PreToolUse", session: "questions", turn: "one", tool: "request_user_input_async", requestID: "request-7", questions: [["title": "Choose a synthetic option"]], time: start.addingTimeInterval(1))
        let reply = try event("UserPromptSubmit", session: "questions", turn: "two", answeredIDs: ["request-7:0"], time: start.addingTimeInterval(2))
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: [prompt, question, reply], hostID: host, receivedAt: start.addingTimeInterval(3))
        let entries = try await repository.journal(JournalQuery(taskID: task.id)).items
        #expect(entries.map(\.kind) == [.question, .questionResolved])
        #expect(entries.map(\.questionID) == ["request-7:0", "request-7:0"])
        #expect(entries.last?.sourceTurnID == "two")
        #expect(!entries.map(\.text).joined().contains("answer"))
    }

    @Test func restartResolvesQuestionOnlyToItsOriginalDetachedTask() async throws {
        let root = try journalRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let host = try await repository.info().hostID
        let first = WorkTask(title: "Original question")
        let second = WorkTask(title: "Later contributor")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: first)))
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: second)))
        let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: "handoff"), directory: "/same")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: first.id, chat: chat, role: nil, initialTurnID: nil)))
        let time = Date.now.addingTimeInterval(1)
        let prompt = try event("UserPromptSubmit", session: "handoff", turn: "a", time: time)
        let question = try event("PreToolUse", session: "handoff", turn: "a", tool: "request_user_input_async", requestID: "request-8", questions: [["title": "Question for first task"]], time: time.addingTimeInterval(1))
        let ingestor = JournalIngestor(repository: repository)
        _ = try await ingestor.ingest(events: [prompt, question], hostID: host, receivedAt: time.addingTimeInterval(2))
        let oldLink = try #require(try await repository.detail(first.id).chatLinks.first)
        _ = try await repository.apply(WorkMutation(change: .detachChat(linkID: oldLink.id)))
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: second.id, chat: chat, role: nil, initialTurnID: nil)))
        let newPrompt = try event("UserPromptSubmit", session: "handoff", turn: "b", time: time.addingTimeInterval(3))
        let reply = try event("UserPromptSubmit", session: "handoff", turn: "c", answeredIDs: ["request-8:0"], time: time.addingTimeInterval(4))
        // This separate ingestion simulates an app restart between question and reply.
        _ = try await JournalIngestor(repository: repository).ingest(events: [newPrompt, reply], hostID: host, receivedAt: time.addingTimeInterval(5))
        #expect(try await repository.journal(JournalQuery(taskID: first.id)).items.map(\.kind) == [.question, .questionResolved])
        #expect(try await repository.journal(JournalQuery(taskID: second.id)).items.isEmpty)
    }

    private func journalRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-journal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func event(
        _ name: String, session: String, turn: String?, child: String? = nil, message: String? = nil,
        tool: String? = nil, requestID: String? = nil, questions: [[String: String]]? = nil,
        answeredIDs: [String]? = nil, time: Date
    ) throws -> AgentEvent {
        var payload: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/synthetic"]
        if let turn { payload["turn_id"] = turn }; if let child { payload["agent_id"] = child }
        if let message { payload["last_assistant_message"] = message }
        if let tool { payload["tool_name"] = tool }; if let requestID { payload["tool_use_id"] = requestID }
        if let questions { payload["tool_input"] = ["questions": questions] }
        if let answeredIDs {
            let replies = answeredIDs.map { ["questionItemId": "[\"request_user_input_async\",\"\($0.dropLast(2))\",\($0.suffix(1))]"] }
            let body = String(data: try JSONSerialization.data(withJSONObject: replies), encoding: .utf8)!
            payload["prompt"] = "<send_user_message_question_reply>\(body)</send_user_message_question_reply>"
        }
        return try AgentEvent(provider: .codex, payload: JSONSerialization.data(withJSONObject: payload), time: time)
    }
}
