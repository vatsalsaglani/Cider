import SwiftUI
import CiderDomain
import CiderUI

struct GraphCanvas: View {
    let snapshot: GraphSnapshot
    @Binding var viewport: GraphViewport
    let onSizeChanged: (CGSize) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var canvasDragTranslation = CGSize.zero
    @State private var nodeDragOrigins: [LinkedEntityID: GraphPoint] = [:]
    @State private var magnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    for edge in snapshot.edges {
                        guard let source = point(edge.source, size: size), let target = point(edge.target, size: size) else { continue }
                        var path = Path(); path.move(to: source); path.addLine(to: target)
                        context.stroke(path, with: .color(edgeColor(edge.kind).opacity(0.7)), lineWidth: 1.5)
                        context.draw(Text(edge.kind.label).font(.caption2).foregroundStyle(CiderColor.textSecondary), at: CGPoint(x: (source.x + target.x) / 2, y: (source.y + target.y) / 2))
                    }
                }
                ForEach(snapshot.nodes) { node in
                    if let point = point(node.id, size: geometry.size) {
                        Button { viewport.select(node.id) } label: { nodeLabel(node) }
                            .buttonStyle(.plain)
                            .position(point)
                            .highPriorityGesture(nodeDrag(node))
                            .accessibilityLabel(accessibilityLabel(node))
                            .accessibilityHint("Select to inspect. Dragging pins only this node's layout position.")
                    }
                }
            }
            .background(CiderColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(CiderColor.borderSubtle))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gesture(canvasDrag)
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                viewport.zoom(by: Double(value.magnification / magnification))
                magnification = value.magnification
            }.onEnded { _ in magnification = 1 })
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: viewport.positions.count)
            .onAppear { onSizeChanged(geometry.size) }
            .onChange(of: geometry.size) { _, size in onSizeChanged(size) }
        }
    }

    @ViewBuilder private func nodeLabel(_ node: GraphNode) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon(node.id.kind)); Text(node.title).lineLimit(1).frame(maxWidth: 130, alignment: .leading)
            if node.attention != nil { Image(systemName: "exclamationmark.bubble") }
            if !node.available { Image(systemName: "questionmark.folder") }
        }
        .font(.caption.weight(.medium)).foregroundStyle(CiderColor.textPrimary).padding(.horizontal, 9).padding(.vertical, 7)
        .background(viewport.selected == node.id ? CiderColor.accentWash : CiderColor.surfaceRaised, in: nodeShape(node.id.kind))
        .overlay(nodeShape(node.id.kind).stroke(viewport.selected == node.id ? CiderColor.focusRing : edgeColor(for: node.id.kind), lineWidth: viewport.selected == node.id ? 2 : 1))
    }
    private func point(_ id: LinkedEntityID, size: CGSize) -> CGPoint? {
        guard let value = viewport.positions[id] else { return nil }
        return CGPoint(x: size.width / 2 + (value.x + viewport.offset.x) * viewport.scale, y: size.height / 2 + (value.y + viewport.offset.y) * viewport.scale)
    }
    private func nodeShape(_ kind: LinkedEntityKind) -> AnyShape {
        switch kind { case .task: return AnyShape(Capsule()); case .chat: return AnyShape(RoundedRectangle(cornerRadius: 9)); case .note: return AnyShape(Diamond()) }
    }
    private func icon(_ kind: LinkedEntityKind) -> String { switch kind { case .task: "checklist"; case .chat: "bubble.left.and.bubble.right"; case .note: "doc.text" } }
    private func edgeColor(_ kind: GraphEdgeKind) -> Color { kind == .contributes ? CiderColor.accent : CiderColor.textSecondary }
    private func edgeColor(for kind: LinkedEntityKind) -> Color { kind == .chat ? CiderColor.accentEnd : CiderColor.borderSubtle }
    private func accessibilityLabel(_ node: GraphNode) -> String { "\(node.id.kind.rawValue.capitalized): \(node.title)\(node.available ? "" : ", unavailable")" }
    private var canvasDrag: some Gesture {
        DragGesture().onChanged { value in
            let delta = CGSize(width: value.translation.width - canvasDragTranslation.width, height: value.translation.height - canvasDragTranslation.height)
            viewport.pan(x: delta.width, y: delta.height)
            canvasDragTranslation = value.translation
        }.onEnded { _ in canvasDragTranslation = .zero }
    }
    private func nodeDrag(_ node: GraphNode) -> some Gesture {
        DragGesture(minimumDistance: 1).onChanged { value in
            let origin = nodeDragOrigins[node.id] ?? viewport.positions[node.id] ?? GraphPoint(x: 0, y: 0)
            nodeDragOrigins[node.id] = origin
            viewport.move(node.id, from: origin, translationX: value.translation.width, translationY: value.translation.height)
        }.onEnded { _ in nodeDragOrigins[node.id] = nil }
    }
}

private struct Diamond: InsettableShape {
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path { let rect = rect.insetBy(dx: insetAmount, dy: insetAmount); var path = Path(); path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.midY)); path.closeSubpath(); return path }
    func inset(by amount: CGFloat) -> Diamond { var copy = self; copy.insetAmount += amount; return copy }
}

private extension GraphEdgeKind { var label: String { switch self { case .contributes: "contributes"; case .noteContext: "context"; case .noteEvidence: "evidence"; case .notePlan: "plan"; case .documentLink: "links to" } } }
