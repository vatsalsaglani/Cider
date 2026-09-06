import Testing
import Foundation
@testable import CiderData
import CiderDomain

@Suite struct LinkedMigrationTests {
    @Test func legacyImportPreservesIDsOrderCompletionPreferencesAndIsIdempotent() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = root.appending(path: "workspace.json")
        let fixture = try #require(Bundle.module.url(forResource: "legacy-workspace-v1", withExtension: "json", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: legacyURL)
        let original = try Data(contentsOf: legacyURL)
        let storeURL = root.appending(path: "work.sqlite")
        let legacy = LegacyImport(workspaceURL: legacyURL, folderPaths: ["/synthetic/root"])
        let store = try await SQLiteWorkRepository.open(at: storeURL, access: .appReadWrite, legacy: legacy)
        let tasks = try await store.tasks(TaskQuery(limit: 10)).items
        #expect(tasks.map(\.id.uuidString) == ["00000000-0000-4000-8000-000000000010", "00000000-0000-4000-8000-000000000011", "00000000-0000-4000-8000-000000000012"])
        #expect(tasks.map(\.sortOrder) == [0, 1, 2])
        #expect(tasks[1].status == .done)
        #expect(try Data(contentsOf: legacyURL) == original)
        #expect(try Data(contentsOf: root.appending(path: "workspace.json.cider-backup")) == original)
        let again = try await SQLiteWorkRepository.open(at: storeURL, access: .appReadWrite, legacy: legacy)
        #expect(try await again.tasks(TaskQuery(limit: 10)).items.count == 3)
        try Data("later legacy corruption".utf8).write(to: legacyURL)
        let afterSourceChanges = try await SQLiteWorkRepository.open(at: storeURL, access: .appReadWrite, legacy: legacy)
        #expect(try await afterSourceChanges.tasks(TaskQuery(limit: 10)).items.count == 3)
        let recovery = root.appending(path: "recovery.json")
        try await store.exportLegacyRecovery(to: recovery)
        #expect(try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: recovery)).tasks.count == 3)
    }

    @Test func malformedLegacyLeavesSourceAndExistingDestinationIntact() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = root.appending(path: "workspace.json"); let bytes = Data("not json".utf8); try bytes.write(to: legacyURL)
        let storeURL = root.appending(path: "work.sqlite")
        await #expect(throws: WorkStoreError.migrationFailed) { try await SQLiteWorkRepository.open(at: storeURL, access: .appReadWrite, legacy: LegacyImport(workspaceURL: legacyURL, folderPaths: [])) }
        #expect(try Data(contentsOf: legacyURL) == bytes)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
