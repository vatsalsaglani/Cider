import Foundation
import CiderDomain

enum WorkQueries {
    static func info(_ database: WorkDatabaseExecutor) async throws -> WorkStoreInfo {
        try await database.rows("SELECT schema_version,revision,host_id FROM metadata WHERE singleton=1").first.map(infoRow) ?? { throw WorkStoreError.unavailable }()
    }
    static func tasks(_ query: TaskQuery, _ database: WorkDatabaseExecutor) async throws -> WorkPage<WorkTask> {
        try WorkLimits.validate(limit: query.limit)
        let info = try await info(database); let offset = try cursor(query.cursor, signature: taskSignature(query), revision: info.revision)
        var clauses = ["1=1"]; var values: [SQLValue] = []
        if let day = query.day { clauses.append("planned_day=?"); values.append(.text(day.id)) }
        if !query.includeDone { clauses.append("status!='done'") }
        if !query.search.isEmpty { clauses.append("(title LIKE ? OR description_markdown LIKE ?)"); values += [.text("%" + query.search + "%"), .text("%" + query.search + "%")] }
        values += [.integer(Int64(query.limit + 1)), .integer(Int64(offset))]
        let sql = "SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks WHERE " + clauses.joined(separator: " AND ") + " ORDER BY planned_day,sort_order,id LIMIT ? OFFSET ?"
        let rows = try await database.rows(sql, values)
        var items: [WorkTask] = []; for row in rows.prefix(query.limit) { items.append(try await taskRow(row, database)) }
        return WorkPage(items: items, nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: taskSignature(query), revision: info.revision) : nil, revision: info.revision)
    }
    static func detail(_ id: UUID, _ database: WorkDatabaseExecutor) async throws -> TaskDetail {
        let info = try await info(database)
        guard let row = try await database.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks WHERE id=?", [.text(id.uuidString.lowercased())]).first else { throw WorkStoreError.notFound }
        let task = try await taskRow(row, database)
        let links = try await chatLinks(taskID: id, database)
        var chats: [ChatReference] = []; for link in links { chats.append(try await chat(link.chat, database)) }
        let noteLinks = try await noteLinks(taskID: id, database)
        var notes: [NoteReference] = []; for link in noteLinks { notes.append(try await note(link.noteID, database)) }
        let count = try await database.scalarInt("SELECT count(*) FROM journal WHERE task_id=?", [.text(id.uuidString.lowercased())])
        return TaskDetail(task: task, chats: chats, chatLinks: links, notes: notes, noteLinks: noteLinks, journalCount: count, revision: info.revision)
    }
    static func folders(_ database: WorkDatabaseExecutor) async throws -> [FolderReference] {
        try await database.rows("SELECT id,path,available FROM folder_roots ORDER BY path").map(folderRow)
    }
    static func note(_ id: UUID, _ database: WorkDatabaseExecutor) async throws -> NoteReference {
        guard let row = try await database.rows("SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes WHERE id=?", [.text(id.uuidString.lowercased())]).first else { throw WorkStoreError.notFound }
        return try noteRow(row)
    }
    static func notes(_ query: NoteQuery, _ database: WorkDatabaseExecutor) async throws -> WorkPage<NoteReference> {
        try WorkLimits.validate(limit: query.limit); let info = try await info(database); let offset = try cursor(query.cursor, signature: noteSignature(query), revision: info.revision)
        var clauses = ["1=1"]; var values: [SQLValue] = []
        if let root = query.rootID { clauses.append("root_id=?"); values.append(.text(root.uuidString.lowercased())) }
        if !query.search.isEmpty { clauses.append("relative_path LIKE ?"); values.append(.text("%" + query.search + "%")) }
        values += [.integer(Int64(query.limit + 1)), .integer(Int64(offset))]
        let sql = "SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes WHERE " + clauses.joined(separator: " AND ") + " ORDER BY relative_path,id LIMIT ? OFFSET ?"
        let rows = try await database.rows(sql, values)
        return WorkPage(items: try rows.prefix(query.limit).map(noteRow), nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: noteSignature(query), revision: info.revision) : nil, revision: info.revision)
    }
    static func journal(_ query: JournalQuery, _ database: WorkDatabaseExecutor) async throws -> WorkPage<JournalEntry> {
        try WorkLimits.validate(limit: query.limit); let info = try await info(database); let offset = try cursor(query.cursor, signature: "j:\(query.taskID):\(query.afterSequence ?? -1)", revision: info.revision)
        let rows = try await database.rows("SELECT sequence,id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution FROM journal WHERE task_id=? AND sequence>? ORDER BY sequence LIMIT ? OFFSET ?", [.text(query.taskID.uuidString.lowercased()), .integer(query.afterSequence ?? 0), .integer(Int64(query.limit + 1)), .integer(Int64(offset))])
        return WorkPage(items: try rows.prefix(query.limit).map(journalRow), nextCursor: rows.count > query.limit ? makeCursor(offset + query.limit, signature: "j:\(query.taskID):\(query.afterSequence ?? -1)", revision: info.revision) : nil, revision: info.revision)
    }
    static func notch(_ database: WorkDatabaseExecutor) async throws -> NotchPreferences {
        guard let value = try await database.scalarText("SELECT value_json FROM preferences WHERE key='notch'") else { return NotchPreferences() }
        return try JSONDecoder().decode(NotchPreferences.self, from: Data(value.utf8))
    }
    static func connections(_ entity: LinkedEntityID, limit: Int, _ database: WorkDatabaseExecutor) async throws -> WorkConnections {
        try WorkLimits.validate(limit: limit); let info = try await info(database)
        switch entity {
        case .task(let id):
            let detail = try await detail(id, database)
            let edges = detail.chatLinks.map { GraphEdge(id: $0.id, source: .chat($0.chat), target: .task(id), kind: .contributes) } + detail.noteLinks.map { GraphEdge(id: $0.id, source: .note($0.noteID), target: .task(id), kind: edgeKind($0.role)) }
            return WorkConnections(entity: entity, tasks: [detail.task], chats: Array(detail.chats.prefix(limit)), notes: Array(detail.notes.prefix(limit)), edges: Array(edges.prefix(limit)), truncated: detail.chats.count > limit || detail.notes.count > limit || edges.count > limit, revision: info.revision)
        case .note(let id):
            let taskRows = try await database.rows("SELECT t.id,t.title,t.description_markdown,t.planned_day,t.due_at,t.status,t.created_at,t.sort_order,t.revision FROM tasks t JOIN task_note_links l ON l.task_id=t.id WHERE l.note_id=? ORDER BY t.planned_day,t.sort_order LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(limit + 1))])
            var tasks: [WorkTask] = []; for row in taskRows.prefix(limit) { tasks.append(try await taskRow(row, database)) }
            let documentRows = try await database.rows("SELECT id,source_id,target_id,fragment FROM note_document_links WHERE source_id=? OR target_id=? ORDER BY id LIMIT ?", [.text(id.uuidString.lowercased()), .text(id.uuidString.lowercased()), .integer(Int64(limit))])
            let links = try documentRows.map(documentLinkRow)
            let noteIDs = Set(links.flatMap { [$0.sourceID, $0.targetID] }).subtracting([id])
            var notes: [NoteReference] = []; for noteID in noteIDs { notes.append(try await note(noteID, database)) }; notes.sort { $0.relativePath < $1.relativePath }
            let edges = tasks.map { GraphEdge(id: UUID(), source: .note(id), target: .task($0.id), kind: .noteContext) } + links.map { GraphEdge(id: $0.id, source: .note($0.sourceID), target: .note($0.targetID), kind: .documentLink) }
            return WorkConnections(entity: entity, tasks: tasks, chats: [], notes: notes, edges: edges, truncated: taskRows.count > limit, revision: info.revision)
        case .chat(let identity):
            let links = try await chatLinks(chat: identity, database)
            var taskRows: [WorkTask] = []; for link in links.prefix(limit) { taskRows.append(try await task(link.taskID, database)) }
            let edges = links.prefix(limit).map { GraphEdge(id: $0.id, source: .chat(identity), target: .task($0.taskID), kind: .contributes) }
            return WorkConnections(entity: entity, tasks: taskRows, chats: [try await chat(identity, database)], notes: [], edges: edges, truncated: links.count > limit, revision: info.revision)
        }
    }
    static func task(_ id: UUID, _ database: WorkDatabaseExecutor) async throws -> WorkTask {
        guard let row = try await database.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks WHERE id=?", [.text(id.uuidString.lowercased())]).first else { throw WorkStoreError.notFound }; return try await taskRow(row, database)
    }
    static func chat(_ identity: ChatIdentity, _ database: WorkDatabaseExecutor) async throws -> ChatReference {
        guard let row = try await database.rows("SELECT title,directory,origin_json,observed_at,current_turn_id,execution,attention FROM chats WHERE host_id=? AND provider=? AND session_id=?", chatValues(identity)).first else { throw WorkStoreError.notFound }
        return ChatReference(identity: identity, title: row[0].string, directory: row[1].string ?? "", origin: row[2].string.flatMap { try? JSONDecoder().decode(AgentOrigin.self, from: Data($0.utf8)) }, observedAt: sqlDate(row[3]), currentTurnID: row[4].string, execution: AgentExecution(rawValue: row[5].string ?? "Unknown") ?? .unknown, attention: row[6].string)
    }
    static func chatLinks(taskID: UUID, _ database: WorkDatabaseExecutor) async throws -> [TaskChatLink] { try await database.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE task_id=? ORDER BY started_at,id", [.text(taskID.uuidString.lowercased())]).map(chatLinkRow) }
    static func chatLinks(chat: ChatIdentity, _ database: WorkDatabaseExecutor) async throws -> [TaskChatLink] { try await database.rows("SELECT id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision FROM task_chat_links WHERE host_id=? AND provider=? AND session_id=? ORDER BY started_at,id", chatValues(chat)).map(chatLinkRow) }
    static func noteLinks(taskID: UUID, _ database: WorkDatabaseExecutor) async throws -> [TaskNoteLink] { try await database.rows("SELECT id,task_id,note_id,role,created_at FROM task_note_links WHERE task_id=? ORDER BY created_at,id", [.text(taskID.uuidString.lowercased())]).map(noteLinkRow) }
    static func taskRow(_ row: [SQLValue], _ database: WorkDatabaseExecutor) async throws -> WorkTask {
        let id = try sqlUUID(row[0]); let criteria = try await database.rows("SELECT id,text,checked,updated_at FROM criteria WHERE task_id=? ORDER BY position", [.text(id.uuidString.lowercased())]).map { try WorkCriterion(id: sqlUUID($0[0]), text: $0[1].string ?? "", checked: $0[2].int64 != 0, updatedAt: sqlDate($0[3]) ?? .distantPast) }
        let dayParts = (row[3].string ?? "").split(separator: "-").compactMap { Int($0) }; guard dayParts.count == 3 else { throw WorkStoreError.unavailable }
        return WorkTask(id: id, title: row[1].string ?? "", descriptionMarkdown: row[2].string ?? "", plannedDay: LocalDay(year: dayParts[0], month: dayParts[1], day: dayParts[2]), dueAt: sqlDate(row[4]), status: WorkTaskStatus(rawValue: row[5].string ?? "") ?? .planned, criteria: criteria, createdAt: sqlDate(row[6]) ?? .distantPast, sortOrder: row[7].int64, revision: row[8].int64)
    }
    static func folderRow(_ row: [SQLValue]) -> FolderReference { FolderReference(id: (try? sqlUUID(row[0])) ?? UUID(), path: row[1].string ?? "", available: row[2].int64 != 0) }
    static func noteRow(_ row: [SQLValue]) throws -> NoteReference { try NoteReference(id: sqlUUID(row[0]), rootID: sqlUUID(row[1]), relativePath: row[2].string ?? "", fileIdentity: row[3].data, available: row[4].int64 != 0, modifiedAt: sqlDate(row[5])) }
    static func chatLinkRow(_ row: [SQLValue]) throws -> TaskChatLink { try TaskChatLink(id: sqlUUID(row[0]), taskID: sqlUUID(row[1]), chat: ChatIdentity(hostID: sqlUUID(row[2]), provider: TrackedProvider(rawValue: row[3].string ?? "") ?? .codex, sessionID: row[4].string ?? ""), role: row[5].string, startedAt: sqlDate(row[6]) ?? .distantPast, endedAt: sqlDate(row[7]), initialTurnID: row[8].string, revision: row[9].int64) }
    static func noteLinkRow(_ row: [SQLValue]) throws -> TaskNoteLink { try TaskNoteLink(id: sqlUUID(row[0]), taskID: sqlUUID(row[1]), noteID: sqlUUID(row[2]), role: NoteRole(rawValue: row[3].string ?? "") ?? .context, createdAt: sqlDate(row[4]) ?? .distantPast) }
    static func documentLinkRow(_ row: [SQLValue]) throws -> NoteDocumentLink { try NoteDocumentLink(id: sqlUUID(row[0]), sourceID: sqlUUID(row[1]), targetID: sqlUUID(row[2]), fragment: row[3].string) }
    static func journalRow(_ row: [SQLValue]) throws -> JournalEntry { let chat: ChatIdentity? = row[4].string.flatMap { _ in try? ChatIdentity(hostID: sqlUUID(row[4]), provider: TrackedProvider(rawValue: row[5].string ?? "") ?? .codex, sessionID: row[6].string ?? "") }; return try JournalEntry(id: sqlUUID(row[1]), sequence: row[0].int64, taskID: sqlUUID(row[2]), linkID: row[3].string.flatMap(UUID.init(uuidString:)), chat: chat, sourceEventID: row[7].string.flatMap(UUID.init(uuidString:)), sourceTurnID: row[8].string, questionID: row[9].string, sourceKey: row[10].string ?? "", occurredAt: sqlDate(row[11]) ?? .distantPast, receivedAt: sqlDate(row[12]) ?? .distantPast, kind: JournalKind(rawValue: row[13].string ?? "") ?? .response, text: row[14].string ?? "", previewOnly: row[15].int64 != 0, attribution: JournalAttribution(rawValue: row[16].string ?? "") ?? .userSelected) }
    static func infoRow(_ row: [SQLValue]) throws -> WorkStoreInfo { try WorkStoreInfo(schemaVersion: Int(row[0].int64), revision: row[1].int64, hostID: sqlUUID(row[2])) }
    static func edgeKind(_ role: NoteRole) -> GraphEdgeKind { switch role { case .context: .noteContext; case .evidence: .noteEvidence; case .plan: .notePlan } }
}

func chatValues(_ chat: ChatIdentity) -> [SQLValue] { [.text(chat.hostID.uuidString.lowercased()), .text(chat.provider.rawValue), .text(chat.sessionID)] }
private func taskSignature(_ query: TaskQuery) -> String { "t:\(query.day?.id ?? ""):\(query.includeDone):\(query.search):\(query.limit)" }
private func noteSignature(_ query: NoteQuery) -> String { "n:\(query.rootID?.uuidString ?? ""):\(query.search):\(query.limit)" }
private func makeCursor(_ offset: Int, signature: String, revision: Int64) -> String { Data("\(revision)|\(offset)|\(signature)".utf8).base64EncodedString() }
private func cursor(_ value: String?, signature: String, revision: Int64) throws -> Int { guard let value else { return 0 }; guard let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8) else { throw WorkStoreError.conflict }; let parts = decoded.split(separator: "|", maxSplits: 2).map(String.init); guard parts.count == 3, Int64(parts[0]) == revision, Int(parts[1]) != nil, parts[2] == signature else { throw WorkStoreError.conflict }; return Int(parts[1])! }
