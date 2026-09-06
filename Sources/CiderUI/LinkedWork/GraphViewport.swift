import Foundation
import CiderDomain

/// Ephemeral canvas state. Positions and pins are presentation preferences, never relationships.
public struct GraphPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct GraphViewport: Sendable {
    public private(set) var offset: GraphPoint
    public private(set) var scale: Double
    public private(set) var selected: LinkedEntityID?
    public private(set) var positions: [LinkedEntityID: GraphPoint]
    public private(set) var pinned: Set<LinkedEntityID>
    public private(set) var layoutIsActive: Bool

    public init(
        offset: GraphPoint = GraphPoint(x: 0, y: 0),
        scale: Double = 1,
        selected: LinkedEntityID? = nil,
        positions: [LinkedEntityID: GraphPoint] = [:],
        pinned: Set<LinkedEntityID> = [],
        layoutIsActive: Bool = false
    ) {
        self.offset = offset; self.scale = scale; self.selected = selected
        self.positions = positions; self.pinned = pinned; self.layoutIsActive = layoutIsActive
    }

    public mutating func pan(x: Double, y: Double) { offset.x += x; offset.y += y }
    public mutating func zoom(by factor: Double) { scale = min(3, max(0.3, scale * factor)) }
    public mutating func select(_ id: LinkedEntityID?) { selected = id }
    public mutating func move(_ id: LinkedEntityID, to point: GraphPoint, pin: Bool = true) {
        positions[id] = point
        if pin { pinned.insert(id) }
    }
    /// Drag translation is in canvas points; dividing by scale keeps the stored layout unscaled.
    public mutating func move(
        _ id: LinkedEntityID,
        from origin: GraphPoint,
        translationX: Double,
        translationY: Double,
        pin: Bool = true
    ) {
        move(id, to: GraphPoint(x: origin.x + translationX / scale, y: origin.y + translationY / scale), pin: pin)
    }
    public mutating func apply(_ result: GraphLayoutResult) {
        for (id, point) in result.positions where !pinned.contains(id) { positions[id] = point }
        positions = positions.filter { result.positions[$0.key] != nil }
        if let selected, positions[selected] == nil { self.selected = nil }
        layoutIsActive = false
    }
    public mutating func resetLayout() { positions = [:]; pinned = []; offset = GraphPoint(x: 0, y: 0); scale = 1 }
    public mutating func setLayoutActive(_ active: Bool) { layoutIsActive = active }
    public mutating func hide() { layoutIsActive = false }
    public mutating func fit(
        to result: GraphLayoutResult,
        canvasWidth: Double,
        canvasHeight: Double,
        padding: Double = 48
    ) {
        guard !result.positions.isEmpty else { return }
        let values = Array(result.positions.values)
        let minX = values.map(\.x).min() ?? 0, maxX = values.map(\.x).max() ?? 0
        let minY = values.map(\.y).min() ?? 0, maxY = values.map(\.y).max() ?? 0
        offset = GraphPoint(x: -(minX + maxX) / 2, y: -(minY + maxY) / 2)
        let usableWidth = max(1, canvasWidth - padding * 2)
        let usableHeight = max(1, canvasHeight - padding * 2)
        let fitted = min(usableWidth / max(1, maxX - minX), usableHeight / max(1, maxY - minY))
        scale = min(3, max(0.3, fitted))
    }
}
