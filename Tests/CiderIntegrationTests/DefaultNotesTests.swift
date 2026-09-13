import Foundation
import Testing
import CiderDomain
import CiderData
@testable import CiderApp

@Suite @MainActor struct DefaultNotesTests {
    @Test func firstNotesRegisterWhileWorkspaceScansWithoutAnAlert() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let suite = "cider.notes.tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: base) }
        let notes = NotesModel(folders: [], defaults: defaults, defaultFolder: base.appending(path: "Cider"))
        let coordinator = LinkedWorkCoordinator(notes: notes)
        let repository = try await SQLiteWorkRepository.open(at: base.appending(path: "test.sqlite"), access: .appReadWrite)
        try await coordinator.start(repository: repository)
        for _ in 0..<5 {
            await notes.create()
            #expect(notes.error == nil)
            #expect(coordinator.error == nil)
            let url = try #require(notes.selected)
            await notes.onScan?([url])
            let opened = Task { try await coordinator.registerNote(url) }
            let scanned = Task { await notes.onScan?([url]) }
            _ = try await opened.value
            await scanned.value
            #expect(coordinator.error == nil)
        }
        let concurrent = base.appending(path: "Cider/Concurrent.md")
        try Data().write(to: concurrent, options: .withoutOverwriting)
        let opens = (0..<8).map { _ in Task { try await coordinator.registerNote(concurrent) } }
        var ids = Set<UUID>()
        for operation in opens { ids.insert(try await operation.value.id) }
        #expect(ids.count == 1)
        let graph = try await repository.graph(GraphQuery(includeIsolated: true))
        #expect(graph.nodes.count == 6)
    }

    @Test func firstNoteCreatesPersistsAndReusesCiderFolder() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let root = base.appending(path: "Documents/Cider")
        let suite = "cider.notes.tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: base) }
        let notes = NotesModel(folders: [], defaults: defaults, defaultFolder: root)
        await notes.create()
        #expect(notes.error == nil)
        let first = try #require(notes.selected)
        #expect(first.deletingLastPathComponent().path == root.path)
        #expect(try String(contentsOf: first, encoding: .utf8).isEmpty)
        #expect(defaults.stringArray(forKey: "workspaceFolders") == [root.path])
        let reopened = NotesModel(defaults: defaults, defaultFolder: root)
        await reopened.create()
        #expect(reopened.folders == [root.standardizedFileURL])
        #expect(reopened.selected != first)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    @Test func selectedFolderWinsAndDefaultFailureDoesNotSaveBrokenRoot() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let existing = base.appending(path: "Work")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let suite = "cider.notes.tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: base) }
        let fallback = base.appending(path: "Cider")
        try Data("An existing file".utf8).write(to: fallback)
        let notes = NotesModel(folders: [existing], defaults: defaults, defaultFolder: fallback)
        await notes.create()
        #expect(notes.selected?.deletingLastPathComponent().path == existing.path)
        let empty = NotesModel(folders: [], defaults: defaults, defaultFolder: fallback)
        await empty.create()
        #expect(empty.error != nil); #expect(empty.folders.isEmpty); #expect(empty.selected == nil)
        #expect(defaults.stringArray(forKey: "workspaceFolders") == nil)
        #expect(try String(contentsOf: fallback, encoding: .utf8) == "An existing file")
    }

    @Test func scanIndexesLinksInUnopenedNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appending(path: "A.md"), b = root.appending(path: "B.md")
        try "See [[B]] and [B](B.md).".write(to: a, atomically: true, encoding: .utf8)
        try "A destination".write(to: b, atomically: true, encoding: .utf8)
        let notes = NotesModel(folders: [root])
        notes.files = [a, b]
        let coordinator = LinkedWorkCoordinator(notes: notes)
        let repository = try await SQLiteWorkRepository.open(at: root.appending(path: "test.sqlite"), access: .appReadWrite)
        try await coordinator.start(repository: repository)
        // The scan callback is also safe to replay after initial asynchronous scanning.
        await notes.onScan?([a, b])
        let graph = try await repository.graph(GraphQuery(includeIsolated: true))
        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
        #expect(graph.edges.first?.kind == .documentLink)
        #expect(notes.selected == nil)
    }
}
