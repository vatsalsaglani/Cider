import Foundation
import CiderDomain

enum WorkJournalTransactions {
    static func attribution(chats: [ChatIdentity], eventIDs: [UUID], database: WorkDatabaseExecutor) async throws -> AttributionSnapshot {
        guard chats.count <= WorkLimits.attributionRows, eventIDs.count <= WorkLimits.eventBatch else { throw WorkStoreError.outputLimit }
        let info = try await WorkQueries.info(database)
        var links: [TaskChatLink] = []
        var episodes: [AssignmentEpisode] = []
        for chat in chats {
            let matched = try await WorkQueries.chatLinks(chat: chat, database)
            links += matched
            for link in matched {
                let rows = try await database.rows("SELECT id,link_id,source_start_id,turn_id,started_at,ended_at FROM assignment_episodes WHERE link_id=? ORDER BY started_at,id", [.text(link.id.uuidString.lowercased())])
                episodes += try rows.map { try AssignmentEpisode(id: sqlUUID($0[0]), linkID: sqlUUID($0[1]), sourceStartID: sqlUUID($0[2]), turnID: $0[3].string, startedAt: sqlDate($0[4]) ?? .distantPast, endedAt: sqlDate($0[5])) }
            }
        }
        guard links.count + episodes.count <= WorkLimits.attributionRows else { throw WorkStoreError.outputLimit }
        var processed: [UUID] = []
        for id in eventIDs { if try await database.scalarInt("SELECT count(*) FROM processed_events WHERE source_event_id=?", [.text(id.uuidString.lowercased())]) > 0 { processed.append(id) } }
        return AttributionSnapshot(revision: info.revision, links: links.sorted { $0.id.uuidString < $1.id.uuidString }, episodes: episodes.sorted { $0.id.uuidString < $1.id.uuidString }, processedEventIDs: processed)
    }
    static func append(_ batch: JournalBatch, database: WorkDatabaseExecutor) async throws -> JournalReceipt {
        try WorkLimits.validate(batch: batch)
        return try await database.transaction { database in
            let current = try database.scalarInt("SELECT revision FROM metadata WHERE singleton=1")
            guard current == batch.expectedRevision else { throw WorkStoreError.conflict }
            var inserted = 0; var duplicate = 0
            for id in batch.processedEventIDs {
                if try database.scalarInt("SELECT count(*) FROM processed_events WHERE source_event_id=?", [.text(id.uuidString.lowercased())]) > 0 { duplicate += 1 }
            }
            for episode in batch.episodes {
                guard try database.scalarInt("SELECT count(*) FROM task_chat_links WHERE id=?", [.text(episode.linkID.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound }
                try database.execute("INSERT INTO assignment_episodes(id,link_id,source_start_id,turn_id,started_at,ended_at) VALUES (?,?,?,?,?,?) ON CONFLICT(link_id,source_start_id) DO UPDATE SET turn_id=excluded.turn_id,ended_at=excluded.ended_at", [.text(episode.id.uuidString.lowercased()), .text(episode.linkID.uuidString.lowercased()), .text(episode.sourceStartID.uuidString.lowercased()), episode.turnID.map(SQLValue.text) ?? .null, dateValue(episode.startedAt), dateValue(episode.endedAt)])
            }
            for entry in batch.entries {
                try validate(entry, database)
                let exists = try database.scalarInt("SELECT count(*) FROM journal WHERE task_id=? AND source_key=?", [.text(entry.taskID.uuidString.lowercased()), .text(entry.sourceKey)]) > 0
                if exists { duplicate += 1; continue }
                var values: [SQLValue] = [.text(entry.id.uuidString.lowercased()), .text(entry.taskID.uuidString.lowercased()), entry.linkID.map { .text($0.uuidString.lowercased()) } ?? .null]
                values += entry.chat.map(chatValues) ?? [.null, .null, .null]
                values += [entry.sourceEventID.map { .text($0.uuidString.lowercased()) } ?? .null, entry.sourceTurnID.map(SQLValue.text) ?? .null, entry.questionID.map(SQLValue.text) ?? .null, .text(entry.sourceKey), dateValue(entry.occurredAt), dateValue(entry.receivedAt), .text(entry.kind.rawValue), .text(entry.text), .integer(entry.previewOnly ? 1 : 0), .text(entry.attribution.rawValue)]
                try database.execute("INSERT INTO journal(id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", values)
                inserted += 1
            }
            for id in batch.processedEventIDs { try database.execute("INSERT OR IGNORE INTO processed_events(source_event_id) VALUES (?)", [.text(id.uuidString.lowercased())]) }
            if inserted > 0 || !batch.episodes.isEmpty || !batch.processedEventIDs.isEmpty { try WorkMutations.bump(database) }
            return JournalReceipt(revision: try database.scalarInt("SELECT revision FROM metadata WHERE singleton=1"), inserted: inserted, duplicate: duplicate)
        }
    }
    private static func validate(_ entry: JournalDraft, _ database: isolated WorkDatabaseExecutor) throws {
        guard try database.scalarInt("SELECT count(*) FROM tasks WHERE id=?", [.text(entry.taskID.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound }
        if let link = entry.linkID {
            guard let row = try database.rows("SELECT task_id,host_id,provider,session_id FROM task_chat_links WHERE id=?", [.text(link.uuidString.lowercased())]).first, row[0].string == entry.taskID.uuidString.lowercased() else { throw WorkStoreError.conflict }
            if let chat = entry.chat, row[1].string != chat.hostID.uuidString.lowercased() || row[2].string != chat.provider.rawValue || row[3].string != chat.sessionID { throw WorkStoreError.conflict }
        } else if entry.chat != nil { throw WorkStoreError.invalidInput }
    }
}
