import Foundation
import CiderDomain

public struct GraphLayoutResult: Sendable, Equatable {
    public var positions: [LinkedEntityID: GraphPoint]
    public init(positions: [LinkedEntityID: GraphPoint]) { self.positions = positions }
}

/// Bounded deterministic layout. Call from a detached task; it has no UI or storage affinity.
public enum GraphLayout {
    public static func compute(
        snapshot: GraphSnapshot,
        preserving existing: [LinkedEntityID: GraphPoint] = [:]
    ) async throws -> GraphLayoutResult {
        let worker = Task.detached(priority: .userInitiated) {
            try await calculate(snapshot: snapshot, preserving: existing)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func calculate(
        snapshot: GraphSnapshot,
        preserving existing: [LinkedEntityID: GraphPoint]
    ) async throws -> GraphLayoutResult {
        let nodes = snapshot.nodes.prefix(1_000).sorted { key($0.id) < key($1.id) }
        var positions: [LinkedEntityID: GraphPoint] = [:]
        positions.reserveCapacity(nodes.count)
        let count = max(nodes.count, 1)
        for (index, node) in nodes.enumerated() {
            if index.isMultiple(of: 32) {
                try Task.checkCancellation()
                await Task.yield()
            }
            if let point = existing[node.id], point.x.isFinite, point.y.isFinite {
                positions[node.id] = point
                continue
            }
            let angle = (Double(index) * 2.399963229728653) + phase(for: node.id)
            let radius = 110 + 18 * sqrt(Double(index + 1) / Double(count)) * 20
            positions[node.id] = GraphPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        try Task.checkCancellation()
        return GraphLayoutResult(positions: positions)
    }

    private static func phase(for id: LinkedEntityID) -> Double {
        Double(stableHash(key(id)) % 10_000) / 10_000 * (.pi * 2)
    }
    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
    private static func key(_ id: LinkedEntityID) -> String {
        switch id {
        case .task(let id): return "task:" + id.uuidString
        case .note(let id): return "note:" + id.uuidString
        case .chat(let chat): return "chat:" + chat.hostID.uuidString + ":" + chat.provider.rawValue + ":" + chat.sessionID
        }
    }
}
