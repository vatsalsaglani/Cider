import Foundation
import CiderDomain

/// Bounded saved-relationship graph projections. SQLite work stays inside one read snapshot.
enum WorkGraphQueries {
    static func graph(_ query: GraphQuery, _ database: WorkDatabaseExecutor) async throws -> GraphSnapshot {
        try WorkLimits.validate(graph: query)
        return try await database.read { try graph(query, $0) }
    }

    private static func graph(_ query: GraphQuery, _ db: isolated WorkDatabaseExecutor) throws -> GraphSnapshot {
        let store = try WorkQueries.info(db)
        switch query.scope {
        case .local(let focus, let depth):
            return try local(query, focus: focus, depth: depth, revision: store.revision, db)
        case .workspace(let rootID):
            return try workspace(query, rootID: rootID, revision: store.revision, db)
        }
    }

    private static func local(_ query: GraphQuery, focus: LinkedEntityID, depth: Int, revision: Int64, _ db: isolated WorkDatabaseExecutor) throws -> GraphSnapshot {
        var nodes: [LinkedEntityID: GraphNode] = [:]
        var edges: [UUID: GraphEdge] = [:]
        var frontier: Set<LinkedEntityID> = [focus]
        var seen = frontier
        var truncated = false
        let focusNode = try node(focus, db)
        nodes[focus] = focusNode // A direct focus always survives ordinary output trimming.

        for _ in 0..<depth where !frontier.isEmpty {
            var next: Set<LinkedEntityID> = []
            for entity in frontier.sorted(by: entityLess) {
                guard edges.count < query.edgeLimit else { truncated = true; break }
                let candidates = try incident(entity, limit: query.edgeLimit - edges.count + 1, db)
                for edge in candidates {
                    if edges[edge.id] != nil { continue }
                    guard edges.count < query.edgeLimit else { truncated = true; break }
                    guard let source = try eligible(edge.source, query, db), let target = try eligible(edge.target, query, db) else { continue }
                    edges[edge.id] = edge; nodes[edge.source] = source; nodes[edge.target] = target
                    next.insert(edge.source); next.insert(edge.target)
                }
                if candidates.count > query.edgeLimit - edges.count { truncated = true }
            }
            frontier = next.subtracting(seen); seen.formUnion(next)
        }
        return finish(nodes: nodes, edges: edges, query: query, focus: focus, revision: revision, truncated: truncated)
    }

    private static func workspace(_ query: GraphQuery, rootID: UUID?, revision: Int64, _ db: isolated WorkDatabaseExecutor) throws -> GraphSnapshot {
        var nodes: [LinkedEntityID: GraphNode] = [:]
        var edges: [UUID: GraphEdge] = [:]
        var truncated = false
        let limit = query.edgeLimit
        if let rootID {
            // Scope relationship SQL by root before applying its limit.
            let noteRows = try db.rows("SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes WHERE root_id=? ORDER BY relative_path,id LIMIT ?", [.text(rootID.uuidString.lowercased()), .integer(Int64(query.nodeLimit + 1))])
            if noteRows.count > query.nodeLimit { truncated = true }
            for row in noteRows.prefix(query.nodeLimit) { let note = try WorkQueries.noteRow(row); let id = LinkedEntityID.note(note.id); if let value = try eligible(id, query, db) { nodes[id] = value } }
            let links = try db.rows("SELECT l.id,l.task_id,l.note_id,l.role FROM task_note_links l JOIN notes n ON n.id=l.note_id WHERE n.root_id=? ORDER BY l.task_id,l.note_id,l.id LIMIT ?", [.text(rootID.uuidString.lowercased()), .integer(Int64(limit + 1))])
            if links.count > limit { truncated = true }
            for row in links.prefix(limit) {
                let edge = try GraphEdge(id: sqlUUID(row[0]), source: .note(sqlUUID(row[2])), target: .task(sqlUUID(row[1])), kind: WorkQueries.edgeKind(NoteRole(rawValue: row[3].string ?? "") ?? .context))
                try add(edge, query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db)
            }
            // Contributor edges are also root-scoped through their root-related task IDs.
            let taskIDs = Set(links.prefix(limit).compactMap { try? sqlUUID($0[1]) })
            for taskID in taskIDs.sorted(by: { $0.uuidString < $1.uuidString }) where edges.count < limit {
                let chats = try db.rows("SELECT id,host_id,provider,session_id FROM task_chat_links WHERE task_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", [.text(taskID.uuidString.lowercased()), .integer(Int64(limit - edges.count + 1))])
                if chats.count > limit - edges.count { truncated = true }
                for row in chats {
                    let edge = try GraphEdge(id: sqlUUID(row[0]), source: .chat(ChatIdentity(hostID: sqlUUID(row[1]), provider: TrackedProvider(rawValue: row[2].string ?? "") ?? .codex, sessionID: row[3].string ?? "")), target: .task(taskID), kind: .contributes)
                    try add(edge, query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db)
                }
            }
            let documents = try db.rows("SELECT d.id,d.source_id,d.target_id,d.fragment FROM note_document_links d JOIN notes n ON n.id=d.source_id OR n.id=d.target_id WHERE n.root_id=? ORDER BY d.id LIMIT ?", [.text(rootID.uuidString.lowercased()), .integer(Int64(limit - edges.count + 1))])
            if documents.count > limit - edges.count { truncated = true }
            for row in documents { let link = try WorkQueries.documentLinkRow(row); try add(GraphEdge(id: link.id, source: .note(link.sourceID), target: .note(link.targetID), kind: .documentLink), query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db) }
        } else {
            let taskRows = try db.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks ORDER BY planned_day,sort_order,id LIMIT ?", [.integer(Int64(query.nodeLimit + 1))])
            if taskRows.count > query.nodeLimit { truncated = true }
            for row in taskRows.prefix(query.nodeLimit) { let task = try WorkQueries.taskRow(row, db); let id = LinkedEntityID.task(task.id); if let value = try eligible(id, query, db) { nodes[id] = value } }
            let noteRows = try db.rows("SELECT id,root_id,relative_path,file_identity,available,modified_at FROM notes ORDER BY relative_path,id LIMIT ?", [.integer(Int64(query.nodeLimit + 1))])
            if noteRows.count > query.nodeLimit { truncated = true }
            for row in noteRows.prefix(query.nodeLimit) { let note = try WorkQueries.noteRow(row); let id = LinkedEntityID.note(note.id); if let value = try eligible(id, query, db) { nodes[id] = value } }
            let chatRows = try db.rows("SELECT host_id,provider,session_id FROM chats ORDER BY host_id,provider,session_id LIMIT ?", [.integer(Int64(query.nodeLimit + 1))])
            if chatRows.count > query.nodeLimit { truncated = true }
            for row in chatRows.prefix(query.nodeLimit) {
                let identity = try ChatIdentity(hostID: sqlUUID(row[0]), provider: TrackedProvider(rawValue: row[1].string ?? "") ?? .codex, sessionID: row[2].string ?? "")
                if let value = try eligible(.chat(identity), query, db) { nodes[.chat(identity)] = value }
            }
            let contributors = try db.rows("SELECT id,task_id,host_id,provider,session_id FROM task_chat_links WHERE ended_at IS NULL ORDER BY id LIMIT ?", [.integer(Int64(limit + 1))])
            if contributors.count > limit { truncated = true }
            for row in contributors.prefix(limit) {
                let identity = try ChatIdentity(hostID: sqlUUID(row[2]), provider: TrackedProvider(rawValue: row[3].string ?? "") ?? .codex, sessionID: row[4].string ?? "")
                let edge = try GraphEdge(id: sqlUUID(row[0]), source: .chat(identity), target: .task(sqlUUID(row[1])), kind: .contributes)
                try add(edge, query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db)
            }
            let links = try db.rows("SELECT id,task_id,note_id,role FROM task_note_links ORDER BY task_id,note_id,id LIMIT ?", [.integer(Int64(limit + 1))])
            if links.count > limit { truncated = true }
            for row in links.prefix(limit) { try add(GraphEdge(id: sqlUUID(row[0]), source: .note(sqlUUID(row[2])), target: .task(sqlUUID(row[1])), kind: WorkQueries.edgeKind(NoteRole(rawValue: row[3].string ?? "") ?? .context)), query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db) }
            let documents = try db.rows("SELECT id,source_id,target_id,fragment FROM note_document_links ORDER BY id LIMIT ?", [.integer(Int64(limit - edges.count + 1))])
            if documents.count > limit - edges.count { truncated = true }
            for row in documents { let link = try WorkQueries.documentLinkRow(row); try add(GraphEdge(id: link.id, source: .note(link.sourceID), target: .note(link.targetID), kind: .documentLink), query: query, nodes: &nodes, edges: &edges, truncated: &truncated, db) }
        }
        return finish(nodes: nodes, edges: edges, query: query, focus: nil, revision: revision, truncated: truncated)
    }

    private static func add(_ edge: GraphEdge, query: GraphQuery, nodes: inout [LinkedEntityID: GraphNode], edges: inout [UUID: GraphEdge], truncated: inout Bool, _ db: isolated WorkDatabaseExecutor) throws {
        guard edges[edge.id] == nil else { return }
        guard edges.count < query.edgeLimit else { truncated = true; return }
        guard let source = try eligible(edge.source, query, db), let target = try eligible(edge.target, query, db) else { return }
        edges[edge.id] = edge; nodes[edge.source] = source; nodes[edge.target] = target
    }

    private static func eligible(_ id: LinkedEntityID, _ query: GraphQuery, _ db: isolated WorkDatabaseExecutor) throws -> GraphNode? {
        if !query.nodeKinds.isEmpty && !query.nodeKinds.contains(id.kind) { return nil }
        let value = try node(id, db)
        if let status = value.taskStatus {
            if !query.includeDone && status == .done { return nil }
            if !query.statuses.isEmpty && !query.statuses.contains(status) { return nil }
        }
        if case .chat(let chat) = id {
            if !query.providers.isEmpty && !query.providers.contains(chat.provider) { return nil }
            if query.activeChatsOnly {
                let reference = try WorkQueries.chat(chat, db)
                guard let observed = reference.observedAt, Date().timeIntervalSince(observed) < 300,
                      reference.execution == .working || reference.attention != nil else { return nil }
            }
        }
        guard query.search.isEmpty || value.title.localizedCaseInsensitiveContains(query.search) || (value.subtitle?.localizedCaseInsensitiveContains(query.search) ?? false) else { return nil }
        return value
    }

    private static func incident(_ id: LinkedEntityID, limit: Int, _ db: isolated WorkDatabaseExecutor) throws -> [GraphEdge] {
        let sqlLimit = SQLValue.integer(Int64(limit))
        switch id {
        case .task(let taskID):
            let chats = try db.rows("SELECT id,host_id,provider,session_id FROM task_chat_links WHERE task_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", [.text(taskID.uuidString.lowercased()), sqlLimit]).map { try GraphEdge(id: sqlUUID($0[0]), source: .chat(ChatIdentity(hostID: sqlUUID($0[1]), provider: TrackedProvider(rawValue: $0[2].string ?? "") ?? .codex, sessionID: $0[3].string ?? "")), target: .task(taskID), kind: .contributes) }
            let notes = try db.rows("SELECT id,note_id,role FROM task_note_links WHERE task_id=? ORDER BY id LIMIT ?", [.text(taskID.uuidString.lowercased()), sqlLimit]).map { try GraphEdge(id: sqlUUID($0[0]), source: .note(sqlUUID($0[1])), target: .task(taskID), kind: WorkQueries.edgeKind(NoteRole(rawValue: $0[2].string ?? "") ?? .context)) }
            return (chats + notes).sorted { $0.id.uuidString < $1.id.uuidString }
        case .note(let noteID):
            let tasks = try db.rows("SELECT id,task_id,role FROM task_note_links WHERE note_id=? ORDER BY id LIMIT ?", [.text(noteID.uuidString.lowercased()), sqlLimit]).map { try GraphEdge(id: sqlUUID($0[0]), source: .note(noteID), target: .task(sqlUUID($0[1])), kind: WorkQueries.edgeKind(NoteRole(rawValue: $0[2].string ?? "") ?? .context)) }
            let docs = try db.rows("SELECT id,source_id,target_id,fragment FROM note_document_links WHERE source_id=? OR target_id=? ORDER BY id LIMIT ?", [.text(noteID.uuidString.lowercased()), .text(noteID.uuidString.lowercased()), sqlLimit]).map { row in let link = try WorkQueries.documentLinkRow(row); return GraphEdge(id: link.id, source: .note(link.sourceID), target: .note(link.targetID), kind: .documentLink) }
            return (tasks + docs).sorted { $0.id.uuidString < $1.id.uuidString }
        case .chat(let chat):
            return try db.rows("SELECT id,task_id FROM task_chat_links WHERE host_id=? AND provider=? AND session_id=? AND ended_at IS NULL ORDER BY id LIMIT ?", chatValues(chat) + [sqlLimit]).map { try GraphEdge(id: sqlUUID($0[0]), source: .chat(chat), target: .task(sqlUUID($0[1])), kind: .contributes) }
        }
    }

    private static func node(_ id: LinkedEntityID, _ db: isolated WorkDatabaseExecutor) throws -> GraphNode {
        switch id {
        case .task(let taskID): let task = try WorkQueries.task(taskID, db); return GraphNode(id: id, title: task.title, subtitle: task.descriptionMarkdown, taskStatus: task.status)
        case .note(let noteID): let note = try WorkQueries.note(noteID, db); return GraphNode(id: id, title: ((note.relativePath as NSString).lastPathComponent as NSString).deletingPathExtension, subtitle: note.relativePath, available: note.available)
        case .chat(let chatID): let chat = try WorkQueries.chat(chatID, db); return GraphNode(id: id, title: chat.title ?? chatID.sessionID, subtitle: chat.directory, execution: chat.execution, attention: chat.attention)
        }
    }
    private static func finish(nodes: [LinkedEntityID: GraphNode], edges: [UUID: GraphEdge], query: GraphQuery, focus: LinkedEntityID?, revision: Int64, truncated: Bool) -> GraphSnapshot {
        var filtered = nodes
        if !query.includeIsolated { let connected = Set(edges.values.flatMap { [$0.source, $0.target] }); filtered = filtered.filter { connected.contains($0.key) || $0.key == focus } }
        var ordered = filtered.values.sorted { entityLess($0.id, $1.id) }
        var didTruncate = truncated || ordered.count > query.nodeLimit
        if let focus, let focusNode = filtered[focus], ordered.count > query.nodeLimit { ordered = [focusNode] + ordered.filter { $0.id != focus }.prefix(max(0, query.nodeLimit - 1)) }
        else { ordered = Array(ordered.prefix(query.nodeLimit)) }
        let ids = Set(ordered.map(\.id)); let orderedEdges = edges.values.filter { ids.contains($0.source) && ids.contains($0.target) }.sorted { $0.id.uuidString < $1.id.uuidString }
        if orderedEdges.count > query.edgeLimit { didTruncate = true }
        return GraphSnapshot(revision: revision, nodes: ordered, edges: Array(orderedEdges.prefix(query.edgeLimit)), truncated: didTruncate)
    }
}

private func entityLess(_ lhs: LinkedEntityID, _ rhs: LinkedEntityID) -> Bool { key(lhs) < key(rhs) }
private func key(_ id: LinkedEntityID) -> String { switch id { case .task(let value), .note(let value): return id.kind.rawValue + value.uuidString; case .chat(let value): return id.kind.rawValue + value.hostID.uuidString + value.provider.rawValue + value.sessionID } }
