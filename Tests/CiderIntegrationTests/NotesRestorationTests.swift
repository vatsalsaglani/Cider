import Foundation
import Testing
@testable import CiderApp

@MainActor struct NotesRestorationTests {
    @Test func restoresExpandedFoldersAndOpenNoteAfterRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let note = root.appending(path: "Plan.md")
        try "Saved plan".write(to: note, atomically: true, encoding: .utf8)
        let name = "cider.restoration." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set([root.path], forKey: "workspaceFolders")
        let first = NotesModel(defaults: defaults)
        #expect(first.expandedFolders.contains(root.path))
        await first.open(note)
        first.expandedFolders.remove(root.path)
        let restored = NotesModel(defaults: defaults)
        #expect(!restored.expandedFolders.contains(root.path))
        for _ in 0..<100 where restored.selected == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(restored.selected == note)
        #expect(restored.tabs == [note])
        #expect(restored.body == "Saved plan")
        #expect(restored.expandedFolders.contains(root.path))
    }
}
