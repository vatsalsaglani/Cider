import Foundation
import CiderDomain

enum WorkGraphQueries {
    static func graph(_ query: GraphQuery, _ database: WorkDatabaseExecutor) async throws -> GraphSnapshot {
        try WorkLimits.validate(graph: query)
        let info = try await WorkQueries.info(database)
        let taskRows = try await database.rows("SELECT id,title,description_markdown,planned_day,due_at,status,created_at,sort_order,revision FROM tasks ORDER BY planned_day,sort_order,id")
        var nodes: [LinkedEntityID: GraphNode] = [:]
        var edges: [GraphEdge] = []
        for row in taskRows {
            let task = try await WorkQueries.taskRow(row, database)
            guard (query.includeDone || task.status != .done), (query.statuses.isEmpty || query.statuses.contains(task.status)), matches(task.title, query.search) else { continue }
            nodes[.task(task.id)] = GraphNode(id: .task(task.id), title: task.title, taskStatus: task.status)
            for link in try await WorkQueries.chatLinks(taskID: task.id, database) {
                let chat = try await WorkQueries.chat(link.chat, database)
                guard (query.providers.isEmpty || query.providers.contains(chat.identity.provider)), (!query.activeChatsOnly || active(chat)) else { continue }
                let chatID = LinkedEntityID.chat(chat.identity)
                nodes[chatID] = GraphNode(id: chatID, title: chat.title ?? chat.identity.sessionID, subtitle: chat.directory, execution: chat.execution, attention: chat.attention)
                edges.append(GraphEdge(id: link.id, source: chatID, target: .task(task.id), kind: .contributes))
            }
            for link in try await WorkQueries.noteLinks(taskID: task.id, database) {
                let note = try await WorkQueries.note(link.noteID, database)
                let noteID = LinkedEntityID.note(note.id)
                nodes[noteID] = GraphNode(id: noteID, title: note.relativePath, subtitle: nil, available: note.available)
                edges.append(GraphEdge(id: link.id, source: noteID, target: .task(task.id), kind: WorkQueries.edgeKind(link.role)))
            }
        }
        let documentRows = try await database.rows("SELECT id,source_id,target_id,fragment FROM note_document_links ORDER BY source_id,target_id,id")
        for row in documentRows {
            let link = try WorkQueries.documentLinkRow(row)
            guard nodes[.note(link.sourceID)] != nil || nodes[.note(link.targetID)] != nil else { continue }
            let source = try await WorkQueries.note(link.sourceID, database); let target = try await WorkQueries.note(link.targetID, database)
            nodes[.note(source.id)] = GraphNode(id: .note(source.id), title: source.relativePath, available: source.available)
            nodes[.note(target.id)] = GraphNode(id: .note(target.id), title: target.relativePath, available: target.available)
            edges.append(GraphEdge(id: link.id, source: .note(source.id), target: .note(target.id), kind: .documentLink))
        }
        if case .workspace(let root) = query.scope, let root {
            var allowed: Set<LinkedEntityID> = []
            for node in nodes.values { if case .note(let id) = node.id { if try await awaitNoteRoot(id, database) == root { allowed.insert(node.id) } } else { allowed.insert(node.id) } }
            edges = edges.filter { allowed.contains($0.source) && allowed.contains($0.target) }; nodes = nodes.filter { allowed.contains($0.key) }
        }
        if case .local(let focus, let depth) = query.scope {
            var seen: Set<LinkedEntityID> = [focus]; var frontier = seen
            for _ in 0..<depth { let next = Set(edges.filter { frontier.contains($0.source) || frontier.contains($0.target) }.flatMap { [$0.source, $0.target] }); frontier = next.subtracting(seen); seen.formUnion(next) }
            nodes = nodes.filter { seen.contains($0.key) }; edges = edges.filter { seen.contains($0.source) && seen.contains($0.target) }
        }
        if !query.includeIsolated { let connected = Set(edges.flatMap { [$0.source, $0.target] }); nodes = nodes.filter { connected.contains($0.key) } }
        if !query.nodeKinds.isEmpty { nodes = nodes.filter { query.nodeKinds.contains($0.key.kind) }; edges = edges.filter { nodes[$0.source] != nil && nodes[$0.target] != nil } }
        let orderedNodes = nodes.values.sorted { key($0.id) < key($1.id) }
        var truncated = orderedNodes.count > query.nodeLimit || edges.count > query.edgeLimit
        var chosen = Array(orderedNodes.prefix(query.nodeLimit)); var chosenIDs = Set(chosen.map(\.id))
        let endpointEdges = edges.filter { chosenIDs.contains($0.source) && chosenIDs.contains($0.target) }
        let chosenEdges = Array(endpointEdges.prefix(query.edgeLimit)); if endpointEdges.count > chosenEdges.count { truncated = true }
        let endpoints = Set(chosenEdges.flatMap { [$0.source, $0.target] }); if !endpoints.isSubset(of: chosenIDs) { truncated = true; chosen = chosen.filter { endpoints.contains($0.id) }; chosenIDs = Set(chosen.map(\.id)) }
        return GraphSnapshot(revision: info.revision, nodes: chosen, edges: chosenEdges, truncated: truncated)
    }
    private static func matches(_ title: String, _ search: String) -> Bool { search.isEmpty || title.localizedCaseInsensitiveContains(search) }
    private static func key(_ id: LinkedEntityID) -> String { switch id { case .task(let value), .note(let value): return id.kind.rawValue + value.uuidString; case .chat(let value): return id.kind.rawValue + value.hostID.uuidString + value.provider.rawValue + value.sessionID } }
    private static func active(_ chat: ChatReference) -> Bool { guard let observed = chat.observedAt, Date().timeIntervalSince(observed) < 300 else { return false }; return chat.execution == .working || chat.attention != nil }
    private static func awaitNoteRoot(_ id: UUID, _ database: WorkDatabaseExecutor) async throws -> UUID { try await WorkQueries.note(id, database).rootID }
}
