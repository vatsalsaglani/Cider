import Foundation
import Testing
import CiderDomain
import CiderData
@testable import CiderApp

@Suite @MainActor struct CLIWriteTests {
    @Test func writesTravelThroughAppAndRefreshTasksAndGraph() async throws {
        let h = try await Harness()
        defer { h.close() }
        var create = CLIWriteCommand(operation: .createTask); create.title = "CLI task"; create.markdown = "Preserve this"
        let created = try await CLIWriteTransport.send(create, store: h.store)
        let task = try #require(created.task)
        #expect(h.app.workTasks.contains { $0.id == task.id })
        var edit = CLIWriteCommand(operation: .updateTask); edit.taskID = task.id
        edit.expectedRevision = task.revision; edit.status = .done
        let updated = try await CLIWriteTransport.send(edit, store: h.store)
        #expect(updated.task?.status == .done)
        #expect(updated.task?.descriptionMarkdown == "Preserve this")
        let stale = try await CLIWriteTransport.send(edit, store: h.store)
        #expect(stale.error == .conflict)
        var note = CLIWriteCommand(operation: .createNote); note.title = "Plan"; note.markdown = "---\ntitle: Plan\n---\nOriginal\n"
        let saved = try await CLIWriteTransport.send(note, store: h.store)
        let reference = try #require(saved.note)
        #expect(saved.error == nil)
        #expect(saved.path?.hasPrefix(h.root.path) == true)
        var link = CLIWriteCommand(operation: .linkNote); link.taskID = task.id; link.noteID = reference.id; link.role = .plan
        #expect(try await CLIWriteTransport.send(link, store: h.store).error == nil)
        let graph = try await h.app.repository!.graph(GraphQuery(includeDone: true, includeIsolated: true))
        #expect(!graph.edges.isEmpty)
        var append = CLIWriteCommand(operation: .appendNote); append.noteID = reference.id
        append.expectedHash = saved.sha256; append.markdown = "Added\n"
        let appended = try await CLIWriteTransport.send(append, store: h.store)
        #expect(appended.error == nil)
        #expect(appended.note?.id == reference.id)
        #expect(try String(contentsOfFile: saved.path!, encoding: .utf8) == note.markdown! + "Added\n")
        #expect(try await CLIWriteTransport.send(append, store: h.store).error == .fileChanged)
        append.operation = .replaceNote; append.expectedHash = appended.sha256; append.markdown = "Replacement\n"
        #expect(try await CLIWriteTransport.send(append, store: h.store).error == nil)
        #expect(try String(contentsOfFile: saved.path!, encoding: .utf8) == "Replacement\n")
        let freshAccess = LinkedNoteService()
        let current = try await h.app.repository!.note(reference.id)
        let folder = try #require(try await h.app.repository!.folders().first { $0.id == reference.rootID })
        #expect(try await freshAccess.read(current, root: folder, maxBytes: WorkLimits.noteBytes).markdown == "Replacement\n")
    }

    @Test func dirtyEditorAndEscapingNamesAreRejectedWithoutTouchingDisk() async throws {
        let h = try await Harness(); defer { h.close() }
        var create = CLIWriteCommand(operation: .createNote); create.title = "../escape"; create.markdown = "Forbidden"
        #expect(await h.writer.execute(create).error == .invalidInput)
        #expect(!FileManager.default.fileExists(atPath: h.root.appending(path: "Cider").path))
        create.title = "Draft"
        let saved = await h.writer.execute(create)
        let path = try #require(saved.path)
        await h.linked.notes.open(URL(fileURLWithPath: path))
        h.linked.notes.body = "Unsaved human draft"
        var edit = CLIWriteCommand(operation: .replaceNote); edit.noteID = saved.note?.id
        edit.expectedHash = saved.sha256; edit.markdown = "CLI replacement"
        #expect(await h.writer.execute(edit).error == .busy)
        #expect(h.linked.notes.body == "Unsaved human draft")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "Forbidden")
        h.linked.notes.body = "Forbidden"
        #expect(await h.writer.execute(edit).error == nil)
        #expect(h.linked.notes.body == "CLI replacement")
    }

    @Test func offlineWritesNeverCreateAStoreAndOneInboxHasOneOwner() async throws {
        let h = try await Harness(); defer { h.close() }
        let second = CLIWriteServer()
        await #expect(throws: WorkStoreError.busy) { try await second.start(store: h.store) { _ in CLIWriteReply() } }
        var command = CLIWriteCommand(operation: .createTask); command.title = "Offline"
        let missing = h.root.appending(path: "missing.sqlite")
        await #expect(throws: WorkStoreError.unavailable) { try await CLIWriteTransport.send(command, store: missing) }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
        h.server.stop()
        await #expect(throws: WorkStoreError.unavailable) { try await CLIWriteTransport.send(command, store: h.store) }
        let writer = h.writer
        try await h.server.start(store: h.store) { await writer.execute($0) }
        #expect(try await CLIWriteTransport.send(command, store: h.store).task?.title == "Offline")
    }

    @Test func concurrentPublicationSurvivesImmediateConsumption() async throws {
        let h = try await Harness(); defer { h.close() }
        let store = h.store
        let ids = try await withThrowingTaskGroup(of: UUID.self) { group in
            for index in 0..<40 {
                group.addTask {
                    var command = CLIWriteCommand(operation: .createTask)
                    command.title = "Concurrent request \(index)"
                    let reply = try await CLIWriteTransport.send(command, store: store)
                    if let error = reply.error { throw error }
                    return try #require(reply.task?.id)
                }
            }
            var result = Set<UUID>()
            for try await id in group { result.insert(id) }
            return result
        }
        #expect(ids.count == 40)
        #expect(h.app.workTasks.count == 40)
    }

    @MainActor final class Harness {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-cli-test-" + UUID().uuidString)
        var store: URL { root.appending(path: "work.sqlite") }
        let suite = "cider-cli-tests." + UUID().uuidString
        let defaults: UserDefaults
        let app: AppModel
        let linked: LinkedWorkCoordinator
        let writer: CLIAppWriter
        let server = CLIWriteServer()
        init() async throws {
            defaults = try #require(UserDefaults(suiteName: suite))
            app = AppModel(storeURL: root.appending(path: "work.sqlite"), legacyURL: root.appending(path: "absent.json"), folderPaths: [])
            linked = LinkedWorkCoordinator(notes: NotesModel(folders: [], defaults: defaults, defaultFolder: root.appending(path: "Cider")))
            writer = CLIAppWriter(app: app, linked: linked)
            await app.load()
            try await linked.start(repository: try #require(app.repository))
            let writer = writer
            try await server.start(store: store) { await writer.execute($0) }
        }
        func close() { server.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
    }
}
