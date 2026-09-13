import Foundation
import CSQLite
import CiderDomain
import Darwin

extension WorkDatabaseExecutor {
    /// SQLite's table-rebuild procedure preserves every referencing row with foreign keys
    /// disabled outside the transaction, then validates all relationships before commit.
    func migrateProviders() throws {
        try backupVersionOne()
        try execute("PRAGMA foreign_keys=OFF")
        defer { try? execute("PRAGMA foreign_keys=ON") }
        do {
            try transaction { db in
                guard try db.scalarInt("PRAGMA user_version") == 1 else { return }
                try db.execute("""
                    CREATE TABLE chats_v2 (
                        host_id TEXT NOT NULL,
                        provider TEXT NOT NULL CHECK (provider IN ('codex','claude','cursor')),
                        session_id TEXT NOT NULL CHECK (length(session_id) > 0),
                        title TEXT,
                        directory TEXT NOT NULL,
                        origin_json TEXT CHECK (origin_json IS NULL OR json_valid(origin_json)),
                        observed_at REAL,
                        current_turn_id TEXT,
                        execution TEXT NOT NULL CHECK (execution IN ('Ready','Working','Finished responding','Interrupted','Ended','Unknown')),
                        attention TEXT,
                        PRIMARY KEY(host_id,provider,session_id)
                    ) STRICT
                    """)
                try db.execute("INSERT INTO chats_v2 SELECT * FROM chats")
                try db.execute("DROP TABLE chats")
                try db.execute("ALTER TABLE chats_v2 RENAME TO chats")
                try db.execute("""
                    CREATE TABLE metadata_v2 (
                        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                        schema_version INTEGER NOT NULL CHECK (schema_version = 2),
                        revision INTEGER NOT NULL CHECK (revision >= 0),
                        host_id TEXT NOT NULL CHECK (length(host_id) = 36),
                        migration_source_hash TEXT
                    ) STRICT
                    """)
                try db.execute("INSERT INTO metadata_v2 SELECT singleton,2,revision,host_id,migration_source_hash FROM metadata")
                try db.execute("DROP TABLE metadata")
                try db.execute("ALTER TABLE metadata_v2 RENAME TO metadata")
                guard try db.rows("PRAGMA foreign_key_check").isEmpty else { throw WorkStoreError.migrationFailed }
                try db.execute("PRAGMA user_version=2")
            }
        } catch { throw WorkStoreError.migrationFailed }
    }

    private func backupVersionOne() throws {
        try perform { db in
            guard let pointer = sqlite3_db_filename(db, "main") else { return }
            let path = String(cString: pointer)
            guard !path.isEmpty else { return } // In-memory fixture.
            let destination = path + ".v1-backup"
            let descriptor = Darwin.open(destination, O_CREAT | O_EXCL | O_WRONLY, 0o600)
            guard descriptor >= 0 else {
                if errno == EEXIST { return } // A previous recovery copy is never overwritten.
                throw WorkStoreError.migrationFailed
            }
            Darwin.close(descriptor)
            var completed = false
            defer { if !completed { try? FileManager.default.removeItem(atPath: destination) } }
            var output: OpaquePointer?
            guard sqlite3_open_v2(destination, &output, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let output else { if let output { sqlite3_close(output) }; throw WorkStoreError.migrationFailed }
            defer { sqlite3_close(output) }
            guard let backup = sqlite3_backup_init(output, "main", db, "main") else { throw WorkStoreError.migrationFailed }
            let result = sqlite3_backup_step(backup, -1)
            let finish = sqlite3_backup_finish(backup)
            guard result == SQLITE_DONE, finish == SQLITE_OK else { throw WorkStoreError.migrationFailed }
            // A source using WAL carries that mode into the copy. Make the backup
            // self-contained so read-only recovery does not need new WAL sidecars.
            guard sqlite3_exec(output, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else { throw WorkStoreError.migrationFailed }
            completed = true
        }
    }
}
