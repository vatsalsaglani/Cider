import Foundation
import Testing
import CSQLite
import CiderDomain
@testable import CiderData

@Suite struct ProviderMigrationTests {
    @Test func failedMigrationRollsBackAndRetainsRecoveryCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "work.sqlite"), host = UUID().uuidString.lowercased()
        let io = WorkDatabaseExecutor()
        try await io.open(path: file.path, readOnly: false)
        try await io.perform { db in
            let schema = try String(contentsOf: WorkDatabaseExecutor.schemaURL, encoding: .utf8)
            #expect(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK)
        }
        try await io.configureWriter()
        try await io.execute("INSERT INTO metadata VALUES (1,1,5,?,NULL)", [.text(host)])
        // Force failure after the chats table has been rebuilt, exercising transaction rollback.
        try await io.execute("CREATE TABLE metadata_v2 (conflicting_column TEXT)")
        await #expect(throws: WorkStoreError.migrationFailed) { try await io.migrateProviders() }
        #expect(try await io.scalarInt("PRAGMA user_version") == 1)
        #expect(try await io.scalarInt("PRAGMA foreign_keys") == 1)
        #expect(try await io.scalarInt("SELECT revision FROM metadata") == 5)
        #expect(try await io.scalarText("SELECT sql FROM sqlite_master WHERE name='chats'")?.contains("cursor") == false)
        await io.close()
        let backup = try await SQLiteWorkRepository.open(at: URL(fileURLWithPath: file.path + ".v1-backup"), access: .cliReadOnly)
        #expect(try await backup.info().schemaVersion == 1)
        #expect(try await backup.info().revision == 5)
    }

    @Test func versionOneMigrationPreservesLinksJournalAndCreatesReadableBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "work.sqlite")
        let io = WorkDatabaseExecutor()
        try await io.open(path: file.path, readOnly: false)
        let host = UUID(), task = UUID(), link = UUID()
        try await io.perform { db in
            let schema = try String(contentsOf: WorkDatabaseExecutor.schemaURL, encoding: .utf8)
            #expect(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK)
        }
        try await io.execute("INSERT INTO metadata VALUES (1,1,7,?,NULL)", [.text(host.uuidString.lowercased())])
        try await io.execute("INSERT INTO tasks VALUES (?,'Preserve me','Description','2026-09-13',NULL,'blocked',100,0,1)", [.text(task.uuidString.lowercased())])
        try await io.execute("INSERT INTO chats VALUES (?,'codex','old','Old chat','/synthetic',NULL,100,'turn','Working',NULL)", [.text(host.uuidString.lowercased())])
        try await io.execute("INSERT INTO task_chat_links VALUES (?,?,?,'codex','old','Role',100,NULL,'turn',1)", [.text(link.uuidString.lowercased()), .text(task.uuidString.lowercased()), .text(host.uuidString.lowercased())])
        try await io.execute("INSERT INTO journal(id,task_id,link_id,host_id,provider,session_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES (?,?,?,?,'codex','old','saved',101,101,'response','Keep this',1,'identifiedTurn')", [.text(UUID().uuidString.lowercased()), .text(task.uuidString.lowercased()), .text(link.uuidString.lowercased()), .text(host.uuidString.lowercased())])
        await io.close()
        let repository = try await SQLiteWorkRepository.open(at: file, access: .appReadWrite)
        #expect(try await repository.info().schemaVersion == 2)
        #expect(try await repository.info().hostID == host)
        #expect(try await repository.info().revision == 7)
        #expect(try await repository.detail(task).chatLinks.first?.id == link)
        #expect(try await repository.detail(task).task.descriptionMarkdown == "Description")
        #expect(try await repository.journal(JournalQuery(taskID: task)).items.first?.text == "Keep this")
        let cursor = ChatReference(identity: ChatIdentity(hostID: host, provider: .cursor, sessionID: "new"), title: "Cursor chat", directory: "/synthetic")
        _ = try await repository.apply(WorkMutation(change: .attachChat(taskID: task, chat: cursor, role: nil, initialTurnID: nil)))
        #expect(try await repository.detail(task).chats.count == 2)
        let reader = try await SQLiteWorkRepository.open(at: file, access: .cliReadOnly)
        #expect(try await reader.graph(GraphQuery(includeDone: true)).nodes.contains { $0.id == .chat(cursor.identity) })
        let backup = try await SQLiteWorkRepository.open(at: URL(fileURLWithPath: file.path + ".v1-backup"), access: .cliReadOnly)
        #expect(try await backup.info().schemaVersion == 1)
        #expect(try await backup.detail(task).chats.count == 1)
        #expect(try await backup.journal(JournalQuery(taskID: task)).items.first?.text == "Keep this")
    }
}
