import Foundation

public enum GraphScope: Codable, Sendable, Hashable {
    case workspace(rootID: UUID?)
    case local(entity: LinkedEntityID, depth: Int)
}

public struct GraphQuery: Codable, Sendable, Equatable {
    public var scope: GraphScope
    public var includeDone: Bool
    public var includeIsolated: Bool
    public var nodeKinds: [LinkedEntityKind]
    public var statuses: [WorkTaskStatus]
    public var activeChatsOnly: Bool
    public var providers: [TrackedProvider]
    public var search: String
    public var nodeLimit: Int
    public var edgeLimit: Int
    public init(
        scope: GraphScope  = .workspace(rootID: nil),
        includeDone: Bool = false,
        includeIsolated: Bool = false,
        nodeKinds: [LinkedEntityKind] = [],
        statuses: [WorkTaskStatus] = [],
        activeChatsOnly: Bool = false,
        providers: [TrackedProvider] = [],
        search: String = "",
        nodeLimit: Int = 250,
        edgeLimit: Int = 600
    ) {
        self.scope = scope
        self.includeDone = includeDone
        self.includeIsolated = includeIsolated
        self.nodeKinds = nodeKinds
        self.statuses = statuses
        self.activeChatsOnly = activeChatsOnly
        self.providers = providers
        self.search = search
        self.nodeLimit = nodeLimit
        self.edgeLimit = edgeLimit
    }
}

public struct GraphNode: Codable, Sendable, Equatable, Identifiable {
    public var id: LinkedEntityID
    public var title: String
    public var subtitle: String?
    public var taskStatus: WorkTaskStatus?
    public var execution: AgentExecution?
    public var attention: String?
    public var available: Bool
    public init(
        id: LinkedEntityID,
        title: String,
        subtitle: String? = nil,
        taskStatus: WorkTaskStatus? = nil,
        execution: AgentExecution? = nil,
        attention: String? = nil,
        available: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.taskStatus = taskStatus
        self.execution = execution
        self.attention = attention
        self.available = available
    }
}

public enum GraphEdgeKind: String, Codable, CaseIterable, Sendable {
    case contributes = "contributes"
    case noteContext = "noteContext"
    case noteEvidence = "noteEvidence"
    case notePlan = "notePlan"
    case documentLink = "documentLink"
}

public struct GraphEdge: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var source: LinkedEntityID
    public var target: LinkedEntityID
    public var kind: GraphEdgeKind
    public init(id: UUID, source: LinkedEntityID, target: LinkedEntityID, kind: GraphEdgeKind) {
        self.id = id
        self.source = source
        self.target = target
        self.kind = kind
    }
}

public struct GraphSnapshot: Codable, Sendable, Equatable {
    public var revision: Int64
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]
    public var truncated: Bool
    public init(revision: Int64, nodes: [GraphNode], edges: [GraphEdge], truncated: Bool = false) {
        self.revision = revision
        self.nodes = nodes
        self.edges = edges
        self.truncated = truncated
    }
}
