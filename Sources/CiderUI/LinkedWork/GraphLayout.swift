import Foundation
import CiderDomain

public struct GraphLayoutResult: Sendable, Equatable {
    public var positions: [LinkedEntityID: GraphPoint]
    public init(positions: [LinkedEntityID: GraphPoint]) { self.positions = positions }
}

/// A finite spring layout on a worker. No timer or simulation survives the result.
public enum GraphLayout {
    public static func compute(snapshot: GraphSnapshot, preserving existing: [LinkedEntityID: GraphPoint] = [:]) async throws -> GraphLayoutResult {
        let worker = Task.detached(priority: .userInitiated) { try calculate(snapshot, preserving: existing) }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private static func calculate(_ snapshot: GraphSnapshot, preserving existing: [LinkedEntityID: GraphPoint]) throws -> GraphLayoutResult {
        try Task.checkCancellation()
        let nodes = snapshot.nodes.prefix(1_000).sorted { key($0.id) < key($1.id) }
        guard !nodes.isEmpty else { return GraphLayoutResult(positions: [:]) }
        let indices = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        let edges = snapshot.edges.prefix(3_000).compactMap { edge -> (Int, Int)? in
            guard let a = indices[edge.source], let b = indices[edge.target], a != b else { return nil }
            return (a, b)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        let fixed = nodes.map { existing[$0.id].map { $0.x.isFinite && $0.y.isFinite } ?? false }
        var points = nodes.enumerated().map { index, node -> GraphPoint in
            if fixed[index], let point = existing[node.id] { return point }
            let angle = Double(index) * 2.399963229728653
            let radius = 48 * sqrt(Double(index))
            return GraphPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        // Place newcomers near saved neighbors while preserving the user's existing arrangement.
        for (a, b) in edges {
            if fixed[a] && !fixed[b] { points[b] = GraphPoint(x: points[a].x + points[b].x * 0.15 + 60, y: points[a].y + points[b].y * 0.15) }
            if fixed[b] && !fixed[a] { points[a] = GraphPoint(x: points[b].x + points[a].x * 0.15 - 60, y: points[b].y + points[a].y * 0.15) }
        }
        // Local repulsion uses spatial buckets; spring attraction follows only saved edges.
        let iterations = nodes.count > 300 ? 40 : 80
        for step in 0..<iterations where fixed.contains(false) {
            try Task.checkCancellation()
            var buckets: [Cell: [Int]] = [:]
            for index in points.indices { buckets[cell(points[index]), default: []].append(index) }
            var forces = Array(repeating: GraphPoint(x: 0, y: 0), count: points.count)
            for index in points.indices where !fixed[index] {
                let p = points[index], bucket = cell(p)
                for dx in -1...1 { for dy in -1...1 {
                    for other in buckets[Cell(x: bucket.x + dx, y: bucket.y + dy)] ?? [] where other != index {
                        var x = p.x - points[other].x, y = p.y - points[other].y
                        if abs(x) + abs(y) < 0.01 { x = index < other ? -1 : 1; y = 0.5 }
                        let distance = max(1, hypot(x, y))
                        guard distance < 180 else { continue }
                        let force = min(12, 1800 / (distance * distance))
                        forces[index].x += x / distance * force
                        forces[index].y += y / distance * force
                    }
                } }
                forces[index].x -= p.x * 0.001
                forces[index].y -= p.y * 0.001
            }
            for (a, b) in edges {
                let x = points[b].x - points[a].x, y = points[b].y - points[a].y
                let distance = max(1, hypot(x, y)), force = (distance - 100) * 0.035
                forces[a].x += x / distance * force; forces[a].y += y / distance * force
                forces[b].x -= x / distance * force; forces[b].y -= y / distance * force
            }
            let cooling = 1 - Double(step) / Double(iterations + 30)
            for index in points.indices where !fixed[index] {
                let magnitude = max(1, hypot(forces[index].x, forces[index].y) / 12)
                points[index].x += forces[index].x / magnitude * cooling
                points[index].y += forces[index].y / magnitude * cooling
            }
        }
        try Task.checkCancellation()
        return GraphLayoutResult(positions: Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, points[$0.offset]) }))
    }
    private struct Cell: Hashable { let x: Int; let y: Int }
    private static func cell(_ point: GraphPoint) -> Cell { Cell(x: Int(floor(point.x / 180)), y: Int(floor(point.y / 180))) }
    private static func key(_ id: LinkedEntityID) -> String {
        switch id {
        case .task(let id): "task:" + id.uuidString
        case .note(let id): "note:" + id.uuidString
        case .chat(let chat): "chat:" + chat.hostID.uuidString + ":" + chat.provider.rawValue + ":" + chat.sessionID
        }
    }
}
