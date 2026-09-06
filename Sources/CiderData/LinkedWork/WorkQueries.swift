import Foundation
import CiderDomain

/// Every multi-row projection runs inside one queue-confined SQLite read transaction.
enum WorkQueries {
    static func info(_ db: WorkDatabaseExecutor) async throws -> WorkStoreInfo { try await db.read { try info($0) } }
    static func tasks(_ query: TaskQuery, _ db: WorkDatabaseExecutor) async throws -> WorkPage<WorkTask> { try await db.read { try tasks(query, $0) } }
    static func detail(_ id: UUID, _ db: WorkDatabaseExecutor) async throws -> TaskDetail { try await db.read { try detail(id, $0) } }
    static func folders(_ db: WorkDatabaseExecutor) async throws -> [FolderReference] { try await db.read { try folders($0) } }
    static func note(_ id: UUID, _ db: WorkDatabaseExecutor) async throws -> NoteReference { try await db.read { try note(id, $0) } }
    static func notes(_ query: NoteQuery, _ db: WorkDatabaseExecutor) async throws -> WorkPage<NoteReference> { try await db.read { try notes(query, $0) } }
    static func journal(_ query: JournalQuery, _ db: WorkDatabaseExecutor) async throws -> WorkPage<JournalEntry> { try await db.read { try journal(query, $0) } }
    static func notch(_ db: WorkDatabaseExecutor) async throws -> NotchPreferences { try await db.read { try notch($0) } }
    static func connections(_ entity: LinkedEntityID, limit: Int, _ db: WorkDatabaseExecutor) async throws -> WorkConnections { try await db.read { try connections(entity, limit: limit, $0) } }

    static func info(_ db: isolated WorkDatabaseExecutor) throws -> WorkStoreInfo { guard let row = try db.rows("SELECT schema_version,revision,host_id FROM metadata WHERE singleton=1").first else { throw WorkStoreError.unavailable }; return try infoRow(row) }
    static func tasks(_ query: TaskQuery, _ db: isolated WorkDatabaseExecutor) throws -> WorkPage<WorkTask> {
        try WorkLimits.validate(limit: query.limit); let store = try info(db); let offset = try cursor(query.cursor, signature: taskSignature(query), revision: store.revision)
        var whereSQL = ["1=1"]; var values: [SQLValue] = []
        if let day = query.day { whereSQL.append("planned_day=?"); values.append(.text(day.id)) }
        if !query.includeDone { whereSQL.append("status!='done'") }
        if !query.search.isEmpty { whereSQL.append("(title LIKE ? OR description_markdown LIKE ?)"); values += [.text("%\(query.search)%"), .text("%\(query.search)%")] }
        values += [.integer(Int64(query.limit + 1)), .integer(Int64(offset))]
        let rows = try db.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks WHERE \(whereSQL.joined(separator: " AND ")) ORDER BY planned_day,sort_order,id LIMIT ? OFFSET ?", values)
        return WorkPage(items: try rows.prefix(query.limit).map { try taskRow($0, db) }, nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: taskSignature(query), revision: store.revision) : nil, revision: store.revision)
    }
    static func detail(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws -> TaskDetail {
        let store = try info(db); let task = try task(id, db)
        let activeRows = try db.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE task_id=? AND ended_at IS NULL ORDER BY started_at,id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(WorkLimits.list + 1))])
        let activeLinks = try activeRows.prefix(WorkLimits.list).map(chatLinkRow)
        let chats = try activeLinks.map { try chat($0.chat, db) }
        let noteRows = try db.rows("SELECT id,task_id,note_id,role,created_at FROM task_note_links WHERE task_id=? ORDER BY created_at,id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(WorkLimits.list + 1))])
        let noteLinks = try noteRows.prefix(WorkLimits.list).map(noteLinkRow); let notes = try noteLinks.map { try note($0.noteID, db) }
        return TaskDetail(task: task, chats: chats, chatLinks: activeLinks, notes: notes, noteLinks: noteLinks, journalCount: try db.scalarInt("SELECT count(*) FROM journal WHERE task_id=?", [.text(id.uuidString.lowercased())]), truncated: activeRows.count > WorkLimits.list || noteRows.count > WorkLimits.list, revision: store.revision)
    }
    static func folders(_ db: isolated WorkDatabaseExecutor) throws -> [FolderReference] { try db.rows("SELECT id,path,available FROM folder_roots ORDER BY path,id").map(folderRow) }
    static func note(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws -> NoteReference { guard let row = try db.rows("SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes WHERE id=?", [.text(id.uuidString.lowercased())]).first else { throw WorkStoreError.notFound }; return try noteRow(row) }
    static func notes(_ query: NoteQuery, _ db: isolated WorkDatabaseExecutor) throws -> WorkPage<NoteReference> {
        try WorkLimits.validate(limit: query.limit); let store = try info(db); let offset = try cursor(query.cursor, signature: noteSignature(query), revision: store.revision)
        var whereSQL = ["1=1"]; var values: [SQLValue] = []
        if let root = query.rootID { whereSQL.append("root_id=?"); values.append(.text(root.uuidString.lowercased())) }
        if !query.search.isEmpty { whereSQL.append("relative_path LIKE ?"); values.append(.text("%\(query.search)%")) }
        values += [.integer(Int64(query.limit + 1)), .integer(Int64(offset))]
        let rows = try db.rows("SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes WHERE \(whereSQL.joined(separator: " AND ")) ORDER BY relative_path,id LIMIT ? OFFSET ?", values)
        return WorkPage(items: try rows.prefix(query.limit).map(noteRow), nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: noteSignature(query), revision: store.revision) : nil, revision: store.revision)
    }
    static func journal(_ query: JournalQuery, _ db: isolated WorkDatabaseExecutor) throws -> WorkPage<JournalEntry> {
        try WorkLimits.validate(limit: query.limit); let store = try info(db); let signature = "j:\(query.taskID):\(query.afterSequence ?? -1)"; let offset = try cursor(query.cursor, signature: signature, revision: store.revision)
        let rows = try db.rows("SELECT sequence,id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution FROM journal WHERE task_id=? AND sequence>? ORDER BY sequence LIMIT ? OFFSET ?", [.text(query.taskID.uuidString.lowercased()), .integer(query.afterSequence ?? 0), .integer(Int64(query.limit + 1)), .integer(Int64(offset))])
        return WorkPage(items: try rows.prefix(query.limit).map(journalRow), nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: signature, revision: store.revision) : nil, revision: store.revision)
    }
    static func notch(_ db: isolated WorkDatabaseExecutor) throws -> NotchPreferences { guard let json = try db.scalarText("SELECT value_json FROM preferences WHERE key='notch'") else { return NotchPreferences() }; return try JSONDecoder().decode(NotchPreferences.self, from: Data(json.utf8)) }
    static func connections(_ entity: LinkedEntityID, limit: Int, _ db: isolated WorkDatabaseExecutor) throws -> WorkConnections {
        try WorkLimits.validate(limit: limit); let store = try info(db)
        switch entity {
        case .task(let id):
            let detail = try detail(id, db); let edges = detail.chatLinks.map { GraphEdge(id: $0.id, source: .chat($0.chat), target: .task(id), kind: .contributes) } + detail.noteLinks.map { GraphEdge(id: $0.id, source: .note($0.noteID), target: .task(id), kind: edgeKind($0.role)) }
            let over = detail.chats.count > limit || detail.notes.count > limit || edges.count > limit
            return WorkConnections(entity: entity, tasks: [detail.task], chats: Array(detail.chats.prefix(limit)), notes: Array(detail.notes.prefix(limit)), edges: Array(edges.prefix(limit)), truncated: over || detail.truncated, revision: store.revision)
        case .note(let id):
            _ = try note(id, db)
            let taskRows = try db.rows("SELECT l.id,l.role,t.id,t.title,t.description_markdown,t.planned_day,t.due_at,t.status,t.created_at,t.sort_order,t.revision FROM task_note_links l JOIN tasks t ON t.id=l.task_id WHERE l.note_id=? ORDER BY t.planned_day,t.sort_order,t.id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(limit + 1))])
            let taskPairs = try taskRows.prefix(limit).map { (try taskRow(Array($0.dropFirst(2)), db), try sqlUUID($0[0]), NoteRole(rawValue: $0[1].string ?? "") ?? .context) }
            let docRows = try db.rows("SELECT id,source_id,target_id,fragment FROM note_document_links WHERE source_id=? OR target_id=? ORDER BY source_id,target_id,id LIMIT ?", [.text(id.uuidString.lowercased()), .text(id.uuidString.lowercased()), .integer(Int64(limit + 1))])
            let docs = try docRows.prefix(limit).map(documentLinkRow); let ids = Set(docs.flatMap { [$0.sourceID,$0.targetID] }).subtracting([id]); let linkedNotes = try ids.sorted { $0.uuidString < $1.uuidString }.prefix(limit).map { try note($0, db) }
            let edges = taskPairs.map { GraphEdge(id: $0.1, source: .note(id), target: .task($0.0.id), kind: edgeKind($0.2)) } + docs.map { GraphEdge(id: $0.id, source: .note($0.sourceID), target: .note($0.targetID), kind: .documentLink) }
            let truncated = taskRows.count > limit || docRows.count > limit || ids.count > limit || edges.count > limit
            return WorkConnections(entity: entity, tasks: taskPairs.map(\.0), chats: [], notes: Array(linkedNotes), edges: Array(edges.prefix(limit)), truncated: truncated, revision: store.revision)
        case .chat(let chatID):
            let rows = try db.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE host_id=? AND provider=? AND session_id=? AND ended_at IS NULL ORDER BY started_at,id LIMIT ?", chatValues(chatID) + [.integer(Int64(limit + 1))])
            let current = try rows.prefix(limit).map(chatLinkRow); let tasks = try current.map { try task($0.taskID, db) }
            let edges = current.map { GraphEdge(id: $0.id, source: .chat(chatID), target: .task($0.taskID), kind: .contributes) }
            return WorkConnections(entity: entity, tasks: tasks, chats: [try chat(chatID, db)], notes: [], edges: edges, truncated: rows.count > limit, revision: store.revision)
        }
    }
    static func task(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws -> WorkTask { guard let row = try db.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks WHERE id=?", [.text(id.uuidString.lowercased())]).first else { throw WorkStoreError.notFound }; return try taskRow(row, db) }
    static func chat(_ id: ChatIdentity, _ db: isolated WorkDatabaseExecutor) throws -> ChatReference { guard let row = try db.rows("SELECT title,directory,origin_json,observed_at,current_turn_id,execution,attention FROM chats WHERE host_id=? AND provider=? AND session_id=?", chatValues(id)).first else { throw WorkStoreError.notFound }; return ChatReference(identity: id, title: row[0].string, directory: row[1].string ?? "", origin: row[2].string.flatMap { try? JSONDecoder().decode(AgentOrigin.self, from: Data($0.utf8)) }, observedAt: sqlDate(row[3]), currentTurnID: row[4].string, execution: AgentExecution(rawValue: row[5].string ?? "Unknown") ?? .unknown, attention: row[6].string) }
    static func chatLinks(taskID: UUID, _ db: isolated WorkDatabaseExecutor) throws -> [TaskChatLink] { try db.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE task_id=? ORDER BY started_at,id", [.text(taskID.uuidString.lowercased())]).map(chatLinkRow) }
    static func chatLinks(chat: ChatIdentity, _ db: isolated WorkDatabaseExecutor) throws -> [TaskChatLink] { try db.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE host_id=? AND provider=? AND session_id=? ORDER BY started_at,id", chatValues(chat)).map(chatLinkRow) }
    static func noteLinks(taskID: UUID, _ db: isolated WorkDatabaseExecutor) throws -> [TaskNoteLink] { try db.rows("SELECT id,task_id,note_id,role,created_at FROM task_note_links WHERE task_id=? ORDER BY created_at,id", [.text(taskID.uuidString.lowercased())]).map(noteLinkRow) }
    static func taskRow(_ row: [SQLValue], _ db: isolated WorkDatabaseExecutor) throws -> WorkTask { let id = try sqlUUID(row[0]); let criteria = try db.rows("SELECT id,text,checked,updated_at FROM criteria WHERE task_id=? ORDER BY position", [.text(id.uuidString.lowercased())]).map { try WorkCriterion(id: sqlUUID($0[0]), text: $0[1].string ?? "", checked: $0[2].int64 != 0, updatedAt: sqlDate($0[3]) ?? .distantPast) }; let day = (row[3].string ?? "").split(separator: "-").compactMap { Int($0) }; guard day.count == 3 else { throw WorkStoreError.unavailable }; return WorkTask(id: id, title: row[1].string ?? "", descriptionMarkdown: row[2].string ?? "", plannedDay: LocalDay(year: day[0], month: day[1], day: day[2]), dueAt: sqlDate(row[4]), status: WorkTaskStatus(rawValue: row[5].string ?? "") ?? .planned, criteria: criteria, createdAt: sqlDate(row[6]) ?? .distantPast, sortOrder: row[7].int64, revision: row[8].int64) }
    static func folderRow(_ row: [SQLValue]) -> FolderReference { FolderReference(id: (try? sqlUUID(row[0])) ?? UUID(), path: row[1].string ?? "", available: row[2].int64 != 0) }
    static func noteRow(_ row: [SQLValue]) throws -> NoteReference { try NoteReference(id: sqlUUID(row[0]), rootID: sqlUUID(row[1]), relativePath: row[2].string ?? "", fileIdentity: row[3].data, available: row[4].int64 != 0, modifiedAt: sqlDate(row[5])) }
    static func chatLinkRow(_ row: [SQLValue]) throws -> TaskChatLink { try TaskChatLink(id: sqlUUID(row[0]), taskID: sqlUUID(row[1]), chat: ChatIdentity(hostID: sqlUUID(row[2]), provider: TrackedProvider(rawValue: row[3].string ?? "") ?? .codex, sessionID: row[4].string ?? ""), role: row[5].string, startedAt: sqlDate(row[6]) ?? .distantPast, endedAt: sqlDate(row[7]), initialTurnID: row[8].string, revision: row[9].int64) }
    static func noteLinkRow(_ row: [SQLValue]) throws -> TaskNoteLink { try TaskNoteLink(id: sqlUUID(row[0]), taskID: sqlUUID(row[1]), noteID: sqlUUID(row[2]), role: NoteRole(rawValue: row[3].string ?? "") ?? .context, createdAt: sqlDate(row[4]) ?? .distantPast) }
    static func documentLinkRow(_ row: [SQLValue]) throws -> NoteDocumentLink { try NoteDocumentLink(id: sqlUUID(row[0]), sourceID: sqlUUID(row[1]), targetID: sqlUUID(row[2]), fragment: row[3].string) }
    static func journalRow(_ row: [SQLValue]) throws -> JournalEntry { let chat = row[4].string.flatMap { _ in try? ChatIdentity(hostID: sqlUUID(row[4]), provider: TrackedProvider(rawValue: row[5].string ?? "") ?? .codex, sessionID: row[6].string ?? "") }; return try JournalEntry(id: sqlUUID(row[1]), sequence: row[0].int64, taskID: sqlUUID(row[2]), linkID: row[3].string.flatMap(UUID.init(uuidString:)), chat: chat, sourceEventID: row[7].string.flatMap(UUID.init(uuidString:)), sourceTurnID: row[8].string, questionID: row[9].string, sourceKey: row[10].string ?? "", occurredAt: sqlDate(row[11]) ?? .distantPast, receivedAt: sqlDate(row[12]) ?? .distantPast, kind: JournalKind(rawValue: row[13].string ?? "") ?? .response, text: row[14].string ?? "", previewOnly: row[15].int64 != 0, attribution: JournalAttribution(rawValue: row[16].string ?? "") ?? .userSelected) }
    static func infoRow(_ row: [SQLValue]) throws -> WorkStoreInfo { try WorkStoreInfo(schemaVersion: Int(row[0].int64), revision: row[1].int64, hostID: sqlUUID(row[2])) }
    static func edgeKind(_ role: NoteRole) -> GraphEdgeKind { switch role { case .context: .noteContext; case .evidence: .noteEvidence; case .plan: .notePlan } }
}
func chatValues(_ chat: ChatIdentity) -> [SQLValue] { [.text(chat.hostID.uuidString.lowercased()), .text(chat.provider.rawValue), .text(chat.sessionID)] }
private func taskSignature(_ query: TaskQuery) -> String { "t:\(query.day?.id ?? ""):\(query.includeDone):\(query.search):\(query.limit)" }
private func noteSignature(_ query: NoteQuery) -> String { "n:\(query.rootID?.uuidString ?? ""):\(query.search):\(query.limit)" }
private func makeCursor(_ offset: Int, signature: String, revision: Int64) -> String { Data("\(revision)|\(offset)|\(signature)".utf8).base64EncodedString() }
private func cursor(_ value: String?, signature: String, revision: Int64) throws -> Int { guard let value else { return 0 }; guard let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8) else { throw WorkStoreError.conflict }; let parts = decoded.split(separator: "|", maxSplits: 2).map(String.init); guard parts.count == 3, Int64(parts[0]) == revision, let offset = Int(parts[1]), parts[2] == signature else { throw WorkStoreError.conflict }; return offset }
