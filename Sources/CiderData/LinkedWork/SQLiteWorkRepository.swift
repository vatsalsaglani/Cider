import Foundation
import CiderDomain

/// SQLite-backed durable work store. The actor serializes repository orchestration;
/// `WorkDatabaseExecutor` owns the queue-confined SQLite connection.
public actor SQLiteWorkRepository: WorkRepository {
    let database: WorkDatabaseExecutor
    let access: StoreAccess
    let location: URL

    init(database: WorkDatabaseExecutor, access: StoreAccess, location: URL) {
        self.database = database
        self.access = access
        self.location = location
    }

    public static func open(at url: URL, access: StoreAccess, legacy: LegacyImport? = nil) async throws -> SQLiteWorkRepository {
        if access == .cliReadOnly && !FileManager.default.fileExists(atPath: url.path) { throw WorkStoreError.unavailable }
        if access == .appReadWrite { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
        let database = WorkDatabaseExecutor()
        do {
            try await database.open(path: url.path, readOnly: access == .cliReadOnly)
            if access == .appReadWrite {
                try await database.configureWriter()
                try await database.installOrVerifySchema()
                if let legacy { try await WorkMigration.importLegacy(legacy, into: database) }
            } else { try await database.verifyReadOnlySchema() }
            return SQLiteWorkRepository(database: database, access: access, location: url)
        } catch { await database.close(); throw error }
    }
    func writable() throws { guard access == .appReadWrite else { throw WorkStoreError.readOnly } }
    public func info() async throws -> WorkStoreInfo { try await WorkQueries.info(database) }
    public func tasks(_ query: TaskQuery) async throws -> WorkPage<WorkTask> { try await WorkQueries.tasks(query, database) }
    public func detail(_ id: UUID) async throws -> TaskDetail { try await WorkQueries.detail(id, database) }
    public func folders() async throws -> [FolderReference] { try await WorkQueries.folders(database) }
    public func note(_ id: UUID) async throws -> NoteReference { try await WorkQueries.note(id, database) }
    public func notes(_ query: NoteQuery) async throws -> WorkPage<NoteReference> { try await WorkQueries.notes(query, database) }
    public func connections(_ entity: LinkedEntityID, limit: Int) async throws -> WorkConnections { try await WorkQueries.connections(entity, limit: limit, database) }
    public func journal(_ query: JournalQuery) async throws -> WorkPage<JournalEntry> { try await WorkQueries.journal(query, database) }
    public func graph(_ query: GraphQuery) async throws -> GraphSnapshot { try await WorkGraphQueries.graph(query, database) }
    public func attribution(chats: [ChatIdentity], eventIDs: [UUID]) async throws -> AttributionSnapshot { try await WorkJournalTransactions.attribution(chats: chats, eventIDs: eventIDs, database: database) }
    public func notchPreferences() async throws -> NotchPreferences { try await WorkQueries.notch(database) }
    public func apply(_ mutation: WorkMutation) async throws -> MutationReceipt { try writable(); return try await WorkMutations.apply(mutation, database: database) }
    public func appendJournal(_ batch: JournalBatch) async throws -> JournalReceipt { try writable(); return try await WorkJournalTransactions.append(batch, database: database) }
    /// Internal explicit rollback aid; normal saves never rewrite a legacy snapshot.
    func exportLegacyRecovery(to url: URL) async throws { try writable(); try JSONEncoder().encode(try await WorkMigration.recoverySnapshot(from: database)).write(to: url, options: .atomic) }
}
