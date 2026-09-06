import Foundation
import Dispatch
import CSQLite
import CiderDomain

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Compiler-checked queue isolation boundary. SQLite pointers never cross it.
actor WorkDatabaseExecutor {
    private let queue = DispatchSerialQueue(label: "app.cider.linked-database", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private var connection: OpaquePointer?
    isolated deinit { if let connection { sqlite3_close(connection) } }
    func open(path: String, readOnly: Bool) throws {
        guard connection == nil else { throw WorkStoreError.conflict }
        let flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, flags | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { if let db { sqlite3_close(db) }; throw WorkStoreError.unavailable }
        connection = db
    }
    func close() { if let connection { sqlite3_close(connection) }; connection = nil }
    static var schemaURL: URL { Bundle.module.url(forResource: "Schema", withExtension: "sql")! }
    /// Narrow test seam retained from the frozen contract; production callers use typed methods.
    func perform<T: Sendable>(_ operation: @Sendable (OpaquePointer) throws -> T) throws -> T {
        guard let connection else { throw WorkStoreError.unavailable }
        return try operation(connection)
    }
    func configureWriter() throws { try executeScript("PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=1500;") }
    func configureBusyHandling() throws { try executeScript("PRAGMA busy_timeout=1500") }
    func installOrVerifySchema() throws {
        let version = try scalarInt("PRAGMA user_version")
        if version == 0 {
            try execute("BEGIN EXCLUSIVE")
            do {
                if try scalarInt("PRAGMA user_version") == 0 {
                    try executeScript(String(contentsOf: Self.schemaURL, encoding: .utf8))
                    try execute("INSERT INTO metadata(singleton,schema_version,revision,host_id) VALUES (1,1,0,?)", [.text(UUID().uuidString.lowercased())])
                }
                try verifySchema()
                try execute("COMMIT")
            } catch { try? execute("ROLLBACK"); throw error }
        } else if version != 1 { throw WorkStoreError.unsupportedSchema }
        try verifySchema()
    }
    func verifyReadOnlySchema() throws { try verifySchema() }
    private func verifySchema() throws {
        guard try scalarInt("PRAGMA user_version") == 1,
              try scalarInt("SELECT count(*) FROM metadata WHERE singleton=1 AND schema_version=1") == 1 else { throw WorkStoreError.unsupportedSchema }
    }
    func transaction<T: Sendable>(_ body: @Sendable (isolated WorkDatabaseExecutor) throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do { let result = try body(self); try execute("COMMIT"); return result } catch { try? execute("ROLLBACK"); throw error }
    }
    func read<T: Sendable>(_ body: @Sendable (isolated WorkDatabaseExecutor) throws -> T) throws -> T {
        try execute("BEGIN")
        do { let result = try body(self); try execute("COMMIT"); return result } catch { try? execute("ROLLBACK"); throw error }
    }
    func readFile(_ url: URL, maxBytes: Int? = nil) throws -> Data {
        let data = try Data(contentsOf: url)
        guard maxBytes == nil || data.count <= maxBytes! else { throw WorkStoreError.outputLimit }
        return data
    }
    func writeFileAtomically(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }
    func execute(_ sql: String, _ values: [SQLValue] = []) throws {
        let statement = try prepare(sql); defer { sqlite3_finalize(statement) }; try bind(values, statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw mappedError(sqlite3_errcode(connection)) }
    }
    func rows(_ sql: String, _ values: [SQLValue] = []) throws -> [[SQLValue]] {
        let statement = try prepare(sql); defer { sqlite3_finalize(statement) }; try bind(values, statement)
        var output: [[SQLValue]] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { return output }
            guard code == SQLITE_ROW else { throw mappedError(code) }
            output.append((0..<sqlite3_column_count(statement)).map { index -> SQLValue in
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: return .integer(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: return .real(sqlite3_column_double(statement, index))
                case SQLITE_TEXT:
                    let pointer = sqlite3_column_text(statement, index)
                    return .text(String(decoding: UnsafeBufferPointer(start: pointer, count: Int(sqlite3_column_bytes(statement, index))), as: UTF8.self))
                case SQLITE_BLOB: return .blob(Data(bytes: sqlite3_column_blob(statement, index), count: Int(sqlite3_column_bytes(statement, index))))
                default: return .null
                }
            })
        }
    }
    func scalarInt(_ sql: String, _ values: [SQLValue] = []) throws -> Int64 { guard let first = try rows(sql, values).first?.first else { throw WorkStoreError.unavailable }; return first.int64 }
    func scalarText(_ sql: String, _ values: [SQLValue] = []) throws -> String? { try rows(sql, values).first?.first?.string }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let connection else { throw WorkStoreError.unavailable }; var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw mappedError(sqlite3_errcode(connection)) }
        return statement
    }
    private func bind(_ values: [SQLValue], _ statement: OpaquePointer) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1); let code: Int32
            switch value {
            case .null: code = sqlite3_bind_null(statement, index)
            case .integer(let value): code = sqlite3_bind_int64(statement, index, value)
            case .real(let value): code = sqlite3_bind_double(statement, index, value)
            case .text(let value):
                let bytes = Array(value.utf8)
                code = bytes.withUnsafeBufferPointer { sqlite3_bind_text(statement, index, $0.baseAddress, Int32(bytes.count), sqliteTransient) }
            case .blob(let value): code = value.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(value.count), sqliteTransient) }
            }
            guard code == SQLITE_OK else { throw WorkStoreError.unavailable }
        }
    }
    private func executeScript(_ sql: String) throws {
        guard let connection else { throw WorkStoreError.unavailable }
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else { throw mappedError(sqlite3_errcode(connection)) }
    }
    private func mappedError(_ code: Int32) -> WorkStoreError {
        switch code { case SQLITE_BUSY, SQLITE_LOCKED: return .busy; case SQLITE_CONSTRAINT: return .conflict; default: return .unavailable }
    }
}

enum SQLValue: Sendable {
    case null, integer(Int64), real(Double), text(String), blob(Data)
    var int64: Int64 { if case .integer(let value) = self { return value }; return 0 }
    var string: String? { if case .text(let value) = self { return value }; return nil }
    var data: Data? { if case .blob(let value) = self { return value }; return nil }
}
func dateValue(_ date: Date?) -> SQLValue { date.map { .real($0.timeIntervalSince1970) } ?? .null }
func sqlDate(_ value: SQLValue) -> Date? { switch value { case .real(let value): Date(timeIntervalSince1970: value); case .integer(let value): Date(timeIntervalSince1970: Double(value)); default: nil } }
func sqlUUID(_ value: SQLValue) throws -> UUID { guard let value = value.string, let id = UUID(uuidString: value) else { throw WorkStoreError.unavailable }; return id }
func encodeJSON<T: Encodable>(_ value: T) throws -> String { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return String(decoding: try encoder.encode(value), as: UTF8.self) }
func decodeJSON<T: Decodable>(_ value: SQLValue, _ type: T.Type) throws -> T { guard let value = value.string else { throw WorkStoreError.unavailable }; return try JSONDecoder().decode(T.self, from: Data(value.utf8)) }
