import Foundation
import CiderDomain
import CiderData

@main struct LinkedWorkSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-linked-smoke-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appending(path: "work.sqlite")
        let repository = try await SQLiteWorkRepository.open(at: database, access: .appReadWrite)
        let task = WorkTask(title: "Synthetic linked work")
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
        let host = try await repository.info().hostID
        for provider in TrackedProvider.allCases {
            let chat = ChatReference(identity: ChatIdentity(hostID: host, provider: provider, sessionID: "fixture-" + provider.rawValue), title: "Same title", directory: root.path)
            _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task.id, chat: chat, role: nil, initialTurnID: nil)))
        }
        let folder = FolderReference(path: root.path)
        _ = try await repository.apply(WorkMutation(change: .registerFolder(folder: folder)))
        let service = LinkedNoteService()
        let note = try await service.create(root: folder, relativeDirectory: "", title: "Context", markdown: "# Synthetic context\n")
        _ = try await repository.apply(WorkMutation(change: .registerNote(note: note)))
        _ = try await repository.apply(WorkMutation(change: .attachNote(taskID: task.id, noteID: note.id, role: .context)))
        let readOnly = try await SQLiteWorkRepository.open(at: database, access: .cliReadOnly)
        let detail = try await readOnly.detail(task.id)
        guard detail.chats.count == TrackedProvider.allCases.count, detail.notes.count == 1, detail.task.status == .planned else { throw WorkStoreError.conflict }
        let connections = try await readOnly.connections(.note(note.id), limit: 100)
        guard connections.tasks.map(\.id) == [task.id] else { throw WorkStoreError.conflict }
        print("Linked work fixture smoke passed: all tracked providers, shared note, restart and backlinks.")
    }
}
