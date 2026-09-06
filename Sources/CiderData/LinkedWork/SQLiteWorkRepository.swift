import Foundation
import Dispatch
import CSQLite
import CiderDomain

/// Contract seed. Plan 02 supplies persistence; no call creates or migrates user data yet.
public actor SQLiteWorkRepository: WorkRepository {
    private init() {}
    public static func open(at: URL, access: StoreAccess, legacy: LegacyImport? = nil) async throws -> SQLiteWorkRepository {
        throw WorkStoreError.notImplemented
    }
    public func info() async throws -> WorkStoreInfo { throw WorkStoreError.notImplemented }
    public func tasks(_ query: TaskQuery) async throws -> WorkPage<WorkTask> { throw WorkStoreError.notImplemented }
    public func detail(_ id: UUID) async throws -> TaskDetail { throw WorkStoreError.notImplemented }
    public func folders() async throws -> [FolderReference] { throw WorkStoreError.notImplemented }
    public func note(_ id: UUID) async throws -> NoteReference { throw WorkStoreError.notImplemented }
    public func notes(_ query: NoteQuery) async throws -> WorkPage<NoteReference> { throw WorkStoreError.notImplemented }
    public func connections(_ entity: LinkedEntityID, limit: Int) async throws -> WorkConnections { throw WorkStoreError.notImplemented }
    public func journal(_ query: JournalQuery) async throws -> WorkPage<JournalEntry> { throw WorkStoreError.notImplemented }
    public func graph(_ query: GraphQuery) async throws -> GraphSnapshot { throw WorkStoreError.notImplemented }
    public func attribution(chats: [ChatIdentity], eventIDs: [UUID]) async throws -> AttributionSnapshot { throw WorkStoreError.notImplemented }
    public func notchPreferences() async throws -> NotchPreferences { throw WorkStoreError.notImplemented }
    public func apply(_ mutation: WorkMutation) async throws -> MutationReceipt { throw WorkStoreError.notImplemented }
    public func appendJournal(_ batch: JournalBatch) async throws -> JournalReceipt { throw WorkStoreError.notImplemented }
}

/// Compiler-checked queue isolation proof for Plan 02. Pointers never leave this actor.
/// Operations return Sendable values and cannot suspend while holding a connection.
actor WorkDatabaseExecutor {
    private let queue = DispatchSerialQueue(label: "app.cider.linked-database", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private var connection: OpaquePointer?
    isolated deinit { if let connection { sqlite3_close(connection) } }

    func open(path: String, readOnly: Bool) throws {
        guard connection == nil else { throw WorkStoreError.conflict }
        let flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, flags | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw WorkStoreError.unavailable
        }
        connection = db
    }
    func perform<T: Sendable>(_ operation: @Sendable (OpaquePointer) throws -> T) throws -> T {
        guard let connection else { throw WorkStoreError.unavailable }
        return try operation(connection)
    }
    func close() { if let connection { sqlite3_close(connection) }; connection = nil }
    static var schemaURL: URL { Bundle.module.url(forResource: "Schema", withExtension: "sql")! }
}
