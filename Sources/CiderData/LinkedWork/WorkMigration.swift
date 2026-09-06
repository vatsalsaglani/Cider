import Foundation
import CiderDomain

enum WorkMigration {
    static func importLegacy(_ legacy: LegacyImport, into database: WorkDatabaseExecutor) async throws {
        guard FileManager.default.fileExists(atPath: legacy.workspaceURL.path) else { return }
        let source: Data
        do { source = try Data(contentsOf: legacy.workspaceURL) } catch { throw WorkStoreError.migrationFailed }
        let snapshot: AppSnapshot
        do { snapshot = try JSONDecoder().decode(AppSnapshot.self, from: source); guard snapshot.version == 1 else { throw WorkStoreError.migrationFailed } }
        catch { throw WorkStoreError.migrationFailed }
        let hash = digest(source)
        let prior = try await database.scalarText("SELECT migration_source_hash FROM metadata WHERE singleton=1")
        if prior != nil { return }
        guard try await database.scalarInt("SELECT count(*) FROM tasks") == 0 else { throw WorkStoreError.migrationFailed }
        let backup = legacy.workspaceURL.deletingLastPathComponent().appending(path: "workspace.json.cider-backup")
        do {
            if !FileManager.default.fileExists(atPath: backup.path) { try source.write(to: backup, options: .atomic) }
            guard try Data(contentsOf: backup) == source else { throw WorkStoreError.migrationFailed }
        } catch { throw WorkStoreError.migrationFailed }
        do {
            try await database.transaction { database in
                for (offset, item) in snapshot.tasks.enumerated() {
                    let task = WorkTask(id: item.id, title: item.title, plannedDay: item.plannedDay, status: item.completed ? .done : .planned, createdAt: item.createdAt, sortOrder: Int64(offset), revision: 1)
                    try insert(task, database)
                }
                for path in legacy.folderPaths.prefix(WorkLimits.roots) {
                    guard !path.isEmpty else { continue }
                    try database.execute("INSERT INTO folder_roots(id,path,available) VALUES (?,?,1)", [.text(UUID().uuidString.lowercased()), .text(path)])
                }
                try database.execute("INSERT INTO preferences(key,value_json) VALUES ('notch',?)", [.text(try encodeJSON(snapshot.notch))])
                try database.execute("UPDATE metadata SET migration_source_hash=? WHERE singleton=1", [.text(hash)])
            }
        } catch { throw WorkStoreError.migrationFailed }
    }

    static func recoverySnapshot(from database: WorkDatabaseExecutor) async throws -> AppSnapshot {
        let page = try await WorkQueries.tasks(TaskQuery(limit: WorkLimits.list), database)
        guard page.nextCursor == nil else { throw WorkStoreError.outputLimit }
        var snapshot = AppSnapshot(); snapshot.tasks = page.items.map(\.legacyItem); snapshot.notch = try await WorkQueries.notch(database)
        return snapshot
    }

    private static func insert(_ task: WorkTask, _ database: isolated WorkDatabaseExecutor) throws {
        try database.execute("INSERT INTO tasks(id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision) VALUES (?,?,?,?,?,?,?,?,?)", [.text(task.id.uuidString.lowercased()), .text(task.title), .text(task.descriptionMarkdown), .text(task.plannedDay.id), dateValue(task.dueAt), .text(task.status.rawValue), dateValue(task.createdAt), .integer(task.sortOrder), .integer(1)])
    }
    private static func digest(_ data: Data) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}
