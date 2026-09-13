import Testing
import Foundation
import CiderDomain
import CiderUI

@Suite struct GraphLayoutTests {
    @Test func layoutIsDeterministicFiniteAndRetainsViewportState() async throws {
        let snapshot = fixture(nodes: 100, edges: 120)
        let first = try await GraphLayout.compute(snapshot: snapshot)
        let second = try await GraphLayout.compute(snapshot: snapshot)
        #expect(first == second)
        #expect(first.positions.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        let selected = try #require(snapshot.nodes.first?.id)
        var viewport = GraphViewport(selected: selected, positions: first.positions)
        viewport.pan(x: 8, y: -3); viewport.pan(x: 4, y: -5); viewport.zoom(by: 1.2)
        #expect(viewport.offset == GraphPoint(x: 12, y: -8))
        viewport.move(selected, from: GraphPoint(x: 1, y: 2), translationX: 12, translationY: -6)
        let updated = try await GraphLayout.compute(snapshot: snapshot, preserving: viewport.positions)
        viewport.apply(updated)
        #expect(viewport.selected == selected); #expect(viewport.positions[selected] == GraphPoint(x: 11, y: -3))
        viewport.fit(
            to: GraphLayoutResult(positions: [
                selected: GraphPoint(x: -100, y: -25),
                snapshot.nodes[1].id: GraphPoint(x: 100, y: 25)
            ]),
            canvasWidth: 420,
            canvasHeight: 360,
            padding: 60
        )
        #expect(viewport.offset == GraphPoint(x: 0, y: 0))
        #expect(viewport.scale == 1.5)
    }

    @Test func layoutCancelsAndSettledOrHiddenViewportDoesNotStayActive() async throws {
        let snapshot = fixture(nodes: 1_000, edges: 3_000)
        let task = Task { try await GraphLayout.compute(snapshot: snapshot) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        var viewport = GraphViewport(); viewport.setLayoutActive(true); viewport.apply(GraphLayoutResult(positions: [:]))
        #expect(!viewport.layoutIsActive)
        viewport.setLayoutActive(true); viewport.hide(); #expect(!viewport.layoutIsActive)
    }

    @Test func ceilingFixtureProducesAtMostOnePositionPerNode() async throws {
        let snapshot = fixture(nodes: 1_000, edges: 3_000)
        let clock = ContinuousClock(); let start = clock.now
        let layout = try await GraphLayout.compute(snapshot: snapshot)
        #expect(layout.positions.count == 1_000)
        #expect(start.duration(to: clock.now) < .seconds(5))
    }

    @Test func savedEdgesPullRelatedNodesTogether() async throws {
        let snapshot = fixture(nodes: 12, edges: 0)
        let source = snapshot.nodes[0].id, target = snapshot.nodes[11].id
        let unlinked = try await GraphLayout.compute(snapshot: snapshot)
        var connected = snapshot
        connected.edges = [GraphEdge(id: UUID(), source: source, target: target, kind: .documentLink)]
        let linked = try await GraphLayout.compute(snapshot: connected)
        func distance(_ layout: GraphLayoutResult) throws -> Double {
            let a = try #require(layout.positions[source]), b = try #require(layout.positions[target])
            return hypot(a.x - b.x, a.y - b.y)
        }
        #expect(try distance(linked) < distance(unlinked))
    }

    private func fixture(nodes: Int, edges: Int) -> GraphSnapshot {
        let values = (0..<nodes).map { GraphNode(id: .task(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!), title: "Task \($0)") }
        let links = (0..<edges).map { index in GraphEdge(id: UUID(), source: values[index % nodes].id, target: values[(index + 1) % nodes].id, kind: .contributes) }
        return GraphSnapshot(revision: 1, nodes: values, edges: links)
    }
}
