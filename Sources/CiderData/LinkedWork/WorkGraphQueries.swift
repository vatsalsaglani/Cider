import Foundation
import CiderDomain

enum WorkGraphQueries {
    static func graph(_ query: GraphQuery, _ database: WorkDatabaseExecutor) async throws -> GraphSnapshot {
        try WorkLimits.validate(graph: query)
        return try await database.read { try graph(query, $0) }
    }
    static func graph(_ query: GraphQuery, _ db: isolated WorkDatabaseExecutor) throws -> GraphSnapshot {
        if case .local(let focus, let depth) = query.scope { return try local(query, focus: focus, depth: depth, db) }
        let store = try WorkQueries.info(db); let fetch = max(query.nodeLimit, query.edgeLimit) + 1
        var nodes: [LinkedEntityID: GraphNode] = [:]; var edges: [GraphEdge] = []; var truncated = false
        var taskSQL = "SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks"
        var taskValues: [SQLValue] = []
        var taskWhere: [String] = []
        if !query.includeDone { taskWhere.append("status!='done'") }
        if !query.statuses.isEmpty { taskWhere.append("status IN (" + Array(repeating: "?", count: query.statuses.count).joined(separator: ",") + ")"); taskValues += query.statuses.map { .text($0.rawValue) } }
        if !query.search.isEmpty { taskWhere.append("(title LIKE ? OR description_markdown LIKE ?)"); taskValues += [.text("%\(query.search)%"), .text("%\(query.search)%")] }
        if !taskWhere.isEmpty { taskSQL += " WHERE " + taskWhere.joined(separator: " AND ") }; taskSQL += " ORDER BY planned_day,sort_order,id LIMIT ?"; taskValues.append(.integer(Int64(fetch)))
        let taskRows = try db.rows(taskSQL, taskValues); truncated = taskRows.count == fetch
        for row in taskRows.prefix(fetch - 1) { let task = try WorkQueries.taskRow(row, db); nodes[.task(task.id)] = GraphNode(id: .task(task.id), title: task.title, taskStatus: task.status) }
        var noteSQL = "SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes"; var noteValues: [SQLValue] = []
        var noteWhere: [String] = []
        if case .workspace(let root) = query.scope, let root { noteWhere.append("root_id=?"); noteValues.append(.text(root.uuidString.lowercased())) }
        if !query.search.isEmpty { noteWhere.append("relative_path LIKE ?"); noteValues.append(.text("%\(query.search)%")) }
        if !noteWhere.isEmpty { noteSQL += " WHERE " + noteWhere.joined(separator: " AND ") }; noteSQL += " ORDER BY relative_path,id LIMIT ?"; noteValues.append(.integer(Int64(fetch)))
        let noteRows = try db.rows(noteSQL, noteValues); truncated = truncated || noteRows.count == fetch
        for row in noteRows.prefix(fetch - 1) { let note = try WorkQueries.noteRow(row); nodes[.note(note.id)] = GraphNode(id: .note(note.id), title: note.relativePath, available: note.available) }
        var chatSQL = "SELECT host_id,provider,session_id,title,directory,origin_json,observed_at,current_turn_id,execution,attention FROM chats"; var chatValuesSQL: [SQLValue] = []; var chatWhere: [String] = []
        if !query.providers.isEmpty { chatWhere.append("provider IN (" + Array(repeating: "?", count: query.providers.count).joined(separator: ",") + ")"); chatValuesSQL += query.providers.map { .text($0.rawValue) } }
        if !query.search.isEmpty { chatWhere.append("(coalesce(title,'') LIKE ? OR directory LIKE ? OR session_id LIKE ?)"); chatValuesSQL += [.text("%\(query.search)%"), .text("%\(query.search)%"), .text("%\(query.search)%")] }
        if !chatWhere.isEmpty { chatSQL += " WHERE " + chatWhere.joined(separator: " AND ") }; chatSQL += " ORDER BY provider,session_id LIMIT ?"; chatValuesSQL.append(.integer(Int64(fetch)))
        let chatRows = try db.rows(chatSQL, chatValuesSQL); truncated = truncated || chatRows.count == fetch
        for row in chatRows.prefix(fetch - 1) {
            let identity = try ChatIdentity(hostID: sqlUUID(row[0]), provider: TrackedProvider(rawValue: row[1].string ?? "") ?? .codex, sessionID: row[2].string ?? "")
            let chat = ChatReference(identity: identity, title: row[3].string, directory: row[4].string ?? "", origin: row[5].string.flatMap { try? JSONDecoder().decode(AgentOrigin.self, from: Data($0.utf8)) }, observedAt: sqlDate(row[6]), currentTurnID: row[7].string, execution: AgentExecution(rawValue: row[8].string ?? "Unknown") ?? .unknown, attention: row[9].string)
            if !query.activeChatsOnly || active(chat) { nodes[.chat(identity)] = GraphNode(id: .chat(identity), title: chat.title ?? identity.sessionID, subtitle: chat.directory, execution: chat.execution, attention: chat.attention) }
        }
        let taskEdgeRows = try db.rows("SELECT id,task_id,host_id,provider,session_id FROM task_chat_links WHERE ended_at IS NULL ORDER BY task_id,id LIMIT ?", [.integer(Int64(query.edgeLimit + 1))])
        let noteEdgeRows = try db.rows("SELECT id,task_id,note_id,role FROM task_note_links ORDER BY task_id,note_id,id LIMIT ?", [.integer(Int64(query.edgeLimit + 1))])
        let docRows = try db.rows("SELECT id,source_id,target_id,fragment FROM note_document_links ORDER BY source_id,target_id,id LIMIT ?", [.integer(Int64(query.edgeLimit + 1))])
        truncated = truncated || taskEdgeRows.count > query.edgeLimit || noteEdgeRows.count > query.edgeLimit || docRows.count > query.edgeLimit
        for row in taskEdgeRows.prefix(query.edgeLimit) { let chat = LinkedEntityID.chat(try ChatIdentity(hostID: sqlUUID(row[2]), provider: TrackedProvider(rawValue: row[3].string ?? "") ?? .codex, sessionID: row[4].string ?? "")); let task = LinkedEntityID.task(try sqlUUID(row[1])); if nodes[chat] != nil && nodes[task] != nil { edges.append(GraphEdge(id: try sqlUUID(row[0]), source: chat, target: task, kind: .contributes)) } }
        for row in noteEdgeRows.prefix(query.edgeLimit) { let note = LinkedEntityID.note(try sqlUUID(row[2])); let task = LinkedEntityID.task(try sqlUUID(row[1])); if nodes[note] != nil && nodes[task] != nil { edges.append(GraphEdge(id: try sqlUUID(row[0]), source: note, target: task, kind: WorkQueries.edgeKind(NoteRole(rawValue: row[3].string ?? "") ?? .context))) } }
        for row in docRows.prefix(query.edgeLimit) { let link = try WorkQueries.documentLinkRow(row); if nodes[.note(link.sourceID)] != nil && nodes[.note(link.targetID)] != nil { edges.append(GraphEdge(id: link.id, source: .note(link.sourceID), target: .note(link.targetID), kind: .documentLink)) } }
        if case .workspace(let root) = query.scope, let root {
            let scopedLinks = try db.rows("SELECT l.id,l.task_id,l.note_id,l.role FROM task_note_links l JOIN notes n ON n.id=l.note_id WHERE n.root_id=? ORDER BY l.task_id,l.note_id,l.id LIMIT ?", [.text(root.uuidString.lowercased()), .integer(Int64(query.edgeLimit + 1))])
            if scopedLinks.count > query.edgeLimit { truncated = true }
            var taskIDs: [UUID] = []
            for row in scopedLinks.prefix(query.edgeLimit) {
                let taskID = try sqlUUID(row[1]); let noteID = try sqlUUID(row[2]); taskIDs.append(taskID)
                nodes[.task(taskID)] = GraphNode(id: .task(taskID), title: try WorkQueries.task(taskID, db).title, taskStatus: try WorkQueries.task(taskID, db).status)
                let note = try WorkQueries.note(noteID, db); nodes[.note(noteID)] = GraphNode(id: .note(noteID), title: note.relativePath, available: note.available)
                edges.append(GraphEdge(id: try sqlUUID(row[0]), source: .note(noteID), target: .task(taskID), kind: WorkQueries.edgeKind(NoteRole(rawValue: row[3].string ?? "") ?? .context)))
            }
            for taskID in Set(taskIDs) {
                let chats = try db.rows("SELECT host_id,provider,session_id FROM task_chat_links WHERE task_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", [.text(taskID.uuidString.lowercased()), .integer(Int64(query.edgeLimit + 1))])
                if chats.count > query.edgeLimit { truncated = true }
                for chatRow in chats.prefix(query.edgeLimit) {
                    let chatID = try ChatIdentity(hostID: sqlUUID(chatRow[0]), provider: TrackedProvider(rawValue: chatRow[1].string ?? "") ?? .codex, sessionID: chatRow[2].string ?? "")
                    let chat = try WorkQueries.chat(chatID, db); nodes[.chat(chatID)] = GraphNode(id: .chat(chatID), title: chat.title ?? chatID.sessionID, subtitle: chat.directory, execution: chat.execution, attention: chat.attention)
                }
            }
            let rootNotes = Set(nodes.keys.filter { key in if case .note(let id) = key { return (try? WorkQueries.note(id, db).rootID) == root }; return false })
            let related = Set(edges.filter { rootNotes.contains($0.source) || rootNotes.contains($0.target) }.flatMap { [$0.source, $0.target] })
            let rootTasks = Set(related.compactMap { if case .task(let id) = $0 { return id }; return nil })
            var allowed = rootNotes.union(related)
            for taskID in rootTasks { allowed.formUnion(edges.filter { $0.source == .task(taskID) || $0.target == .task(taskID) }.flatMap { [$0.source, $0.target] }) }
            nodes = nodes.filter { allowed.contains($0.key) }; edges = edges.filter { allowed.contains($0.source) && allowed.contains($0.target) }
        }
        if case .local(let focus, let depth) = query.scope { var seen: Set<LinkedEntityID> = [focus]; var frontier = seen; for _ in 0..<depth { let next = Set(edges.filter { frontier.contains($0.source) || frontier.contains($0.target) }.flatMap { [$0.source,$0.target] }); frontier = next.subtracting(seen); seen.formUnion(next) }; nodes = nodes.filter { seen.contains($0.key) }; edges = edges.filter { seen.contains($0.source) && seen.contains($0.target) } }
        if !query.nodeKinds.isEmpty { nodes = nodes.filter { query.nodeKinds.contains($0.key.kind) }; edges = edges.filter { nodes[$0.source] != nil && nodes[$0.target] != nil } }
        if !query.includeIsolated { let connected = Set(edges.flatMap { [$0.source,$0.target] }); nodes = nodes.filter { connected.contains($0.key) } }
        let sorted = nodes.values.sorted { key($0.id) < key($1.id) }; if sorted.count > query.nodeLimit { truncated = true }
        let chosen = Array(sorted.prefix(query.nodeLimit)); let ids = Set(chosen.map(\.id)); let selectedEdges = Array(edges.filter { ids.contains($0.source) && ids.contains($0.target) }.sorted { $0.id.uuidString < $1.id.uuidString }.prefix(query.edgeLimit)); if selectedEdges.count < edges.filter({ ids.contains($0.source) && ids.contains($0.target) }).count { truncated = true }
        return GraphSnapshot(revision: store.revision, nodes: chosen, edges: selectedEdges, truncated: truncated)
    }
    private static func local(_ query: GraphQuery, focus: LinkedEntityID, depth: Int, _ db: isolated WorkDatabaseExecutor) throws -> GraphSnapshot {
        let store = try WorkQueries.info(db)
        var nodes: [LinkedEntityID: GraphNode] = [focus: try node(focus, db)]
        var edges: [GraphEdge] = []; var frontier: Set<LinkedEntityID> = [focus]; var seen = frontier; var truncated = false
        for _ in 0..<depth {
            var next: Set<LinkedEntityID> = []
            for entity in frontier {
                let found = try incident(entity, limit: query.edgeLimit + 1, db)
                if found.count > query.edgeLimit { truncated = true }
                for edge in found.prefix(query.edgeLimit) {
                    edges.append(edge)
                    for endpoint in [edge.source, edge.target] where nodes[endpoint] == nil { nodes[endpoint] = try node(endpoint, db) }
                    next.formUnion([edge.source, edge.target])
                }
            }
            frontier = next.subtracting(seen); seen.formUnion(next)
        }
        if !query.includeDone { nodes = nodes.filter { $0.value.taskStatus != .done || $0.key == focus } }
        if !query.statuses.isEmpty { nodes = nodes.filter { $0.value.taskStatus == nil || query.statuses.contains($0.value.taskStatus!) || $0.key == focus } }
        if !query.nodeKinds.isEmpty { nodes = nodes.filter { query.nodeKinds.contains($0.key.kind) || $0.key == focus } }
        if !query.search.isEmpty { nodes = nodes.filter { $0.key == focus || $0.value.title.localizedCaseInsensitiveContains(query.search) || ($0.value.subtitle?.localizedCaseInsensitiveContains(query.search) ?? false) } }
        edges = edges.filter { nodes[$0.source] != nil && nodes[$0.target] != nil }
        if !query.includeIsolated, edges.isEmpty { nodes = [focus: try node(focus, db)] }
        var ordered = nodes.values.sorted { key($0.id) < key($1.id) }
        if ordered.count > query.nodeLimit { truncated = true; ordered = [try node(focus, db)] + ordered.filter { $0.id != focus }.prefix(max(0, query.nodeLimit - 1)) }
        let ids = Set(ordered.map(\.id)); let resultEdges = Array(edges.filter { ids.contains($0.source) && ids.contains($0.target) }.sorted { $0.id.uuidString < $1.id.uuidString }.prefix(query.edgeLimit))
        return GraphSnapshot(revision: store.revision, nodes: ordered, edges: resultEdges, truncated: truncated)
    }
    private static func incident(_ entity: LinkedEntityID, limit: Int, _ db: isolated WorkDatabaseExecutor) throws -> [GraphEdge] {
        switch entity {
        case .task(let id):
            let chats = try db.rows("SELECT id,host_id,provider,session_id FROM task_chat_links WHERE task_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(limit))]).map { try GraphEdge(id: sqlUUID($0[0]), source: .chat(ChatIdentity(hostID: sqlUUID($0[1]), provider: TrackedProvider(rawValue: $0[2].string ?? "") ?? .codex, sessionID: $0[3].string ?? "")), target: .task(id), kind: .contributes) }
            let notes = try db.rows("SELECT id,note_id,role FROM task_note_links WHERE task_id=? ORDER BY id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(limit))]).map { try GraphEdge(id: sqlUUID($0[0]), source: .note(sqlUUID($0[1])), target: .task(id), kind: WorkQueries.edgeKind(NoteRole(rawValue: $0[2].string ?? "") ?? .context)) }
            return chats + notes
        case .note(let id):
            let tasks = try db.rows("SELECT id,task_id,role FROM task_note_links WHERE note_id=? ORDER BY id LIMIT ?", [.text(id.uuidString.lowercased()), .integer(Int64(limit))]).map { try GraphEdge(id: sqlUUID($0[0]), source: .note(id), target: .task(sqlUUID($0[1])), kind: WorkQueries.edgeKind(NoteRole(rawValue: $0[2].string ?? "") ?? .context)) }
            let docs = try db.rows("SELECT id,source_id,target_id,fragment FROM note_document_links WHERE source_id=? OR target_id=? ORDER BY id LIMIT ?", [.text(id.uuidString.lowercased()), .text(id.uuidString.lowercased()), .integer(Int64(limit))]).map { row in let link = try WorkQueries.documentLinkRow(row); return GraphEdge(id: link.id, source: .note(link.sourceID), target: .note(link.targetID), kind: .documentLink) }
            return tasks + docs
        case .chat(let chat):
            return try db.rows("SELECT id,task_id FROM task_chat_links WHERE host_id=? AND provider=? AND session_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", chatValues(chat) + [.integer(Int64(limit))]).map { try GraphEdge(id: sqlUUID($0[0]), source: .chat(chat), target: .task(sqlUUID($0[1])), kind: .contributes) }
        }
    }
    private static func node(_ id: LinkedEntityID, _ db: isolated WorkDatabaseExecutor) throws -> GraphNode {
        switch id {
        case .task(let taskID): let task = try WorkQueries.task(taskID, db); return GraphNode(id: id, title: task.title, taskStatus: task.status)
        case .note(let noteID): let note = try WorkQueries.note(noteID, db); return GraphNode(id: id, title: note.relativePath, available: note.available)
        case .chat(let chatID): let chat = try WorkQueries.chat(chatID, db); return GraphNode(id: id, title: chat.title ?? chat.identity.sessionID, subtitle: chat.directory, execution: chat.execution, attention: chat.attention)
        }
    }
    private static func active(_ chat: ChatReference) -> Bool { guard let observed = chat.observedAt, Date().timeIntervalSince(observed) < 300 else { return false }; return chat.execution == .working || chat.attention != nil }
    private static func key(_ id: LinkedEntityID) -> String { switch id { case .task(let value), .note(let value): id.kind.rawValue + value.uuidString; case .chat(let value): id.kind.rawValue + value.hostID.uuidString + value.provider.rawValue + value.sessionID } }
}
