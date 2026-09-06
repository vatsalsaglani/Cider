import Foundation
import CiderDomain

enum WorkMutations {
    static func apply(_ mutation: WorkMutation, database: WorkDatabaseExecutor) async throws -> MutationReceipt {
        try await database.transaction { database in
            let hash = try encodeJSON(mutation.change)
            if let stored = try database.scalarText("SELECT result_json FROM mutation_receipts WHERE command_id=?", [.text(mutation.commandID.uuidString.lowercased())]) {
                guard try database.scalarText("SELECT request_hash FROM mutation_receipts WHERE command_id=?", [.text(mutation.commandID.uuidString.lowercased())]) == hash else { throw WorkStoreError.conflict }
                return try JSONDecoder().decode(MutationReceipt.self, from: Data(stored.utf8))
            }
            let current = try database.scalarInt("SELECT revision FROM metadata WHERE singleton=1")
            if let expected = mutation.expectedRevision, expected != current { throw WorkStoreError.conflict }
            let entity = try change(mutation.change, database)
            let revision = try database.scalarInt("SELECT revision FROM metadata WHERE singleton=1")
            let receipt = MutationReceipt(revision: revision, entity: entity)
            try database.execute("INSERT INTO mutation_receipts(command_id,request_hash,result_json) VALUES (?,?,?)", [.text(mutation.commandID.uuidString.lowercased()), .text(hash), .text(try encodeJSON(receipt))])
            return receipt
        }
    }
    private static func change(_ change: WorkChange, _ database: isolated WorkDatabaseExecutor) throws -> LinkedEntityID? {
        switch change {
        case .saveTask(let task):
            try WorkLimits.validate(task: task)
            if task.revision == 0 {
                guard try database.scalarInt("SELECT count(*) FROM tasks WHERE id=?", [.text(task.id.uuidString.lowercased())]) == 0 else { throw WorkStoreError.conflict }
                try write(task, revision: 1, database); try bump(database); return .task(task.id)
            }
            let changed = try database.scalarInt("SELECT count(*) FROM tasks WHERE id=? AND revision=?", [.text(task.id.uuidString.lowercased()), .integer(task.revision)])
            guard changed == 1 else { throw WorkStoreError.conflict }
            try write(task, revision: task.revision + 1, database); try bump(database); return .task(task.id)
        case .deleteTask(let taskID):
            guard try database.scalarInt("SELECT count(*) FROM tasks WHERE id=?", [.text(taskID.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound }
            try database.execute("DELETE FROM tasks WHERE id=?", [.text(taskID.uuidString.lowercased())]); try bump(database); return .task(taskID)
        case .attachChat(let taskID, let chat, let role, let initialTurnID):
            try taskExists(taskID, database); try validate(chat: chat, role: role)
            try upsert(chat, database)
            let existing = try database.rows("SELECT id FROM task_chat_links WHERE task_id=? AND host_id=? AND provider=? AND session_id=? AND ended_at IS NULL", [.text(taskID.uuidString.lowercased())] + chatValues(chat.identity)).first
            if existing != nil { return .task(taskID) }
            try database.execute("INSERT INTO task_chat_links(id,task_id,host_id,provider,session_id,role,started_at,ended_at,initial_turn_id,revision) VALUES (?,?,?,?,?,?,?,NULL,?,1)", [.text(UUID().uuidString.lowercased()), .text(taskID.uuidString.lowercased())] + chatValues(chat.identity) + [role.map(SQLValue.text) ?? .null, dateValue(Date()), initialTurnID.map(SQLValue.text) ?? .null])
            try bump(database); return .task(taskID)
        case .observeChats(let chats):
            guard chats.count <= WorkLimits.attributionRows else { throw WorkStoreError.outputLimit }
            for chat in chats { try validate(chat: chat, role: nil); try updateKnown(chat, database) }
            return nil
        case .detachChat(let linkID):
            guard try database.scalarInt("SELECT count(*) FROM task_chat_links WHERE id=?", [.text(linkID.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound }
            try database.execute("UPDATE task_chat_links SET ended_at=?,revision=revision+1 WHERE id=? AND ended_at IS NULL", [dateValue(Date()), .text(linkID.uuidString.lowercased())]); try bump(database); return nil
        case .attachNote(let taskID, let noteID, let role):
            try taskExists(taskID, database); try noteExists(noteID, database)
            if let existing = try database.rows("SELECT id FROM task_note_links WHERE task_id=? AND note_id=?", [.text(taskID.uuidString.lowercased()), .text(noteID.uuidString.lowercased())]).first {
                try database.execute("UPDATE task_note_links SET role=? WHERE id=?", [.text(role.rawValue), existing[0]]); try bump(database); return .task(taskID)
            }
            try database.execute("INSERT INTO task_note_links(id,task_id,note_id,role,created_at) VALUES (?,?,?,?,?)", [.text(UUID().uuidString.lowercased()), .text(taskID.uuidString.lowercased()), .text(noteID.uuidString.lowercased()), .text(role.rawValue), dateValue(Date())]); try bump(database); return .task(taskID)
        case .detachNote(let linkID):
            guard try database.scalarInt("SELECT count(*) FROM task_note_links WHERE id=?", [.text(linkID.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound }
            try database.execute("DELETE FROM task_note_links WHERE id=?", [.text(linkID.uuidString.lowercased())]); try bump(database); return nil
        case .registerFolder(let folder):
            guard !folder.path.isEmpty else { throw WorkStoreError.invalidInput }
            let count = try database.scalarInt("SELECT count(*) FROM folder_roots WHERE id=?", [.text(folder.id.uuidString.lowercased())])
            let total = try database.scalarInt("SELECT count(*) FROM folder_roots")
            if count == 0 && total >= WorkLimits.roots { throw WorkStoreError.outputLimit }
            try database.execute("INSERT INTO folder_roots(id,path,available) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET path=excluded.path,available=excluded.available", [.text(folder.id.uuidString.lowercased()), .text(folder.path), .integer(folder.available ? 1 : 0)]); try bump(database); return nil
        case .registerNote(let note):
            try rootExists(note.rootID, database); try validate(note: note)
            try database.execute("INSERT INTO notes(id,root_id,relative_path,file_identity,available,modified_at) VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET root_id=excluded.root_id,relative_path=excluded.relative_path,file_identity=excluded.file_identity,available=excluded.available,modified_at=excluded.modified_at", [.text(note.id.uuidString.lowercased()), .text(note.rootID.uuidString.lowercased()), .text(note.relativePath), note.fileIdentity.map(SQLValue.blob) ?? .null, .integer(note.available ? 1 : 0), dateValue(note.modifiedAt)]); try bump(database); return .note(note.id)
        case .setFolderAvailable(let rootID, let available):
            try rootExists(rootID, database); try database.execute("UPDATE folder_roots SET available=? WHERE id=?", [.integer(available ? 1 : 0), .text(rootID.uuidString.lowercased())]); try bump(database); return nil
        case .replaceDocumentLinks(let source, let links):
            try noteExists(source, database); guard links.count <= WorkLimits.list, links.allSatisfy({ $0.sourceID == source }) else { throw WorkStoreError.invalidInput }
            for link in links { try noteExists(link.targetID, database) }
            try database.execute("DELETE FROM note_document_links WHERE source_id=?", [.text(source.uuidString.lowercased())])
            for link in links { try database.execute("INSERT INTO note_document_links(id,source_id,target_id,fragment) VALUES (?,?,?,?)", [.text(link.id.uuidString.lowercased()), .text(link.sourceID.uuidString.lowercased()), .text(link.targetID.uuidString.lowercased()), link.fragment.map(SQLValue.text) ?? .null]) }
            try bump(database); return .note(source)
        case .appendUserNote(let taskID, let text):
            try taskExists(taskID, database); guard !text.isEmpty, text.utf8.count <= 16_384 else { throw WorkStoreError.invalidInput }
            try database.execute("INSERT INTO journal(id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES (?,?,NULL,NULL,NULL,NULL,NULL,NULL,NULL,?,?,?,?,?,?,?)", [.text(UUID().uuidString.lowercased()), .text(taskID.uuidString.lowercased()), .text("user:\(UUID().uuidString.lowercased())"), dateValue(Date()), dateValue(Date()), .text(JournalKind.userNote.rawValue), .text(text), .integer(0), .text(JournalAttribution.userSelected.rawValue)]); try bump(database); return .task(taskID)
        case .setNotch(let preferences):
            try database.execute("INSERT INTO preferences(key,value_json) VALUES ('notch',?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json", [.text(try encodeJSON(preferences))]); try bump(database); return nil
        }
    }
    private static func write(_ task: WorkTask, revision: Int64, _ database: isolated WorkDatabaseExecutor) throws {
        try database.execute("INSERT INTO tasks(id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision) VALUES (?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,description_markdown=excluded.description_markdown,planned_day=excluded.planned_day,due_at=excluded.due_at,status=excluded.status,created_at=excluded.created_at,sort_order=excluded.sort_order,revision=excluded.revision", [.text(task.id.uuidString.lowercased()), .text(task.title), .text(task.descriptionMarkdown), .text(task.plannedDay.id), dateValue(task.dueAt), .text(task.status.rawValue), dateValue(task.createdAt), .integer(task.sortOrder), .integer(revision)])
        try database.execute("DELETE FROM criteria WHERE task_id=?", [.text(task.id.uuidString.lowercased())])
        for (index, criterion) in task.criteria.enumerated() { try database.execute("INSERT INTO criteria(id,task_id,position,text,checked,updated_at) VALUES (?,?,?,?,?,?)", [.text(criterion.id.uuidString.lowercased()), .text(task.id.uuidString.lowercased()), .integer(Int64(index)), .text(criterion.text), .integer(criterion.checked ? 1 : 0), dateValue(criterion.updatedAt)]) }
    }
    static func bump(_ database: isolated WorkDatabaseExecutor) throws { try database.execute("UPDATE metadata SET revision=revision+1 WHERE singleton=1") }
    private static func taskExists(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws { guard try db.scalarInt("SELECT count(*) FROM tasks WHERE id=?", [.text(id.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound } }
    private static func noteExists(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws { guard try db.scalarInt("SELECT count(*) FROM notes WHERE id=?", [.text(id.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound } }
    private static func rootExists(_ id: UUID, _ db: isolated WorkDatabaseExecutor) throws { guard try db.scalarInt("SELECT count(*) FROM folder_roots WHERE id=?", [.text(id.uuidString.lowercased())]) == 1 else { throw WorkStoreError.notFound } }
    private static func validate(chat: ChatReference, role: String?) throws { guard !chat.identity.sessionID.isEmpty, !chat.directory.isEmpty, role?.count ?? 0 <= 120 else { throw WorkStoreError.invalidInput } }
    private static func validate(note: NoteReference) throws { guard !note.relativePath.isEmpty, !note.relativePath.hasPrefix("/"), !note.relativePath.split(separator: "/").contains("..") else { throw WorkStoreError.invalidInput } }
    private static func upsert(_ chat: ChatReference, _ db: isolated WorkDatabaseExecutor) throws { let origin = try chat.origin.map(encodeJSON); try db.execute("INSERT INTO chats(host_id,provider,session_id,title,directory,origin_json,observed_at,current_turn_id,execution,attention) VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT(host_id,provider,session_id) DO UPDATE SET title=excluded.title,directory=excluded.directory,origin_json=excluded.origin_json,observed_at=excluded.observed_at,current_turn_id=excluded.current_turn_id,execution=excluded.execution,attention=excluded.attention", chatValues(chat.identity) + [chat.title.map(SQLValue.text) ?? .null, .text(chat.directory), origin.map(SQLValue.text) ?? .null, dateValue(chat.observedAt), chat.currentTurnID.map(SQLValue.text) ?? .null, .text(chat.execution.rawValue), chat.attention.map(SQLValue.text) ?? .null]) }
    private static func updateKnown(_ chat: ChatReference, _ db: isolated WorkDatabaseExecutor) throws { if try db.scalarInt("SELECT count(*) FROM chats WHERE host_id=? AND provider=? AND session_id=?", chatValues(chat.identity)) > 0 { try upsert(chat, db); try bump(db) } }
}
