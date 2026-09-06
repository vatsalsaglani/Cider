import Testing
import Foundation
@testable import CiderData
import CiderDomain

@Suite struct LinkedGraphTests {
    @Test func graphMatchesBacklinksAcrossAttachDetachAndRelaunch() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "work.sqlite")
        let store = try await SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let task = WorkTask(title: "Saved relationship")
        let folder = FolderReference(path: "/synthetic")
        let note = NoteReference(rootID: folder.id, relativePath: "evidence.md")
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        _ = try await store.apply(WorkMutation(change: .registerFolder(folder: folder)))
        _ = try await store.apply(WorkMutation(change: .registerNote(note: note)))
        let chat = ChatReference(identity: ChatIdentity(hostID: try await store.info().hostID, provider: .codex, sessionID: "same-title"), title: "Duplicate", directory: "/synthetic")
        _ = try await store.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        _ = try await store.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: note.id, role: .evidence)))
        let graph = try await store.graph(GraphQuery(includeDone: true, includeIsolated: true, nodeLimit: 50, edgeLimit: 50))
        let backlinks = try await store.connections(.note(note.id), limit: 50)
        #expect(Set(graph.edges.map(\.id)).isSuperset(of: Set(backlinks.edges.map(\.id))))
        let noteLink = try #require(try await store.detail(task.id).noteLinks.first)
        _ = try await store.apply(WorkMutation(change: .detachNote(linkID: noteLink.id)))
        let reopened = try await SQLiteWorkRepository.open(at: url, access: .appReadWrite)
        let after = try await reopened.graph(GraphQuery(includeDone: true, includeIsolated: true, nodeLimit: 50, edgeLimit: 50))
        #expect(!after.edges.contains { $0.id == noteLink.id })
    }

    @Test func duplicateTitlesRemainDistinctAndFilterBoundsAreRespected() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try await SQLiteWorkRepository.open(at: root.appending(path: "work.sqlite"), access: .appReadWrite)
        let task = WorkTask(title: "Shared title")
        _ = try await store.apply(WorkMutation(change: .saveTask(task: task)))
        let host = try await store.info().hostID
        for suffix in ["one", "two"] {
            let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: .codex, sessionID: suffix), title: "Same chat", directory: "/synthetic")
            _ = try await store.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        }
        let graph = try await store.graph(GraphQuery(includeDone: true, includeIsolated: true, nodeKinds: [.chat], providers: [.codex], nodeLimit: 2, edgeLimit: 1))
        #expect(Set(graph.nodes.map(\.id)).count == graph.nodes.count)
        #expect(graph.nodes.filter { $0.title == "Same chat" }.count == 2)
        #expect(graph.nodes.count <= 2); #expect(graph.edges.count <= 1); #expect(graph.truncated)
    }

    private func root() throws -> URL { let url = FileManager.default.temporaryDirectory.appending(path: "cider-graph-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
}
