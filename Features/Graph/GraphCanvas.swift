import SwiftUI
import CiderDomain
import CiderUI

struct GraphCanvas: View {
    let snapshot: GraphSnapshot
    @Binding var viewport: GraphViewport
    let onSizeChanged: (CGSize) -> Void
    let open: (LinkedEntityID) -> Void
    @State private var canvasDragTranslation = CGSize.zero
    @State private var nodeDragOrigins: [LinkedEntityID: GraphPoint] = [:]
    @State private var magnification: CGFloat = 1
    @State private var hovered: LinkedEntityID?

    private var focus: LinkedEntityID? {
        guard let id = hovered ?? viewport.selected, snapshot.nodes.contains(where: { $0.id == id }) else { return nil }
        return id
    }
    private var neighbors: Set<LinkedEntityID> {
        guard let focus else { return [] }
        return Set(snapshot.edges.filter { $0.source == focus || $0.target == focus }.flatMap { [$0.source, $0.target] }).union([focus])
    }
    var body: some View {
        GeometryReader { geometry in
            let connected = neighbors
            ZStack {
                Canvas { context, size in
                    for edge in snapshot.edges {
                        guard let source = point(edge.source, size: size), let target = point(edge.target, size: size) else { continue }
                        let highlighted = focus == edge.source || focus == edge.target
                        var path = Path(); path.move(to: source); path.addLine(to: target)
                        context.stroke(path, with: .color(highlighted ? CiderColor.accent.opacity(0.85) : CiderColor.textSecondary.opacity(focus == nil ? 0.2 : 0.06)), lineWidth: highlighted ? 1.5 : 0.8)
                    }
                }.allowsHitTesting(false)
                ForEach(snapshot.nodes) { node in
                    if let point = point(node.id, size: geometry.size) {
                        Button { viewport.select(node.id) } label: { nodeLabel(node, emphasized: focus == nil || connected.contains(node.id)) }
                            .buttonStyle(.plain).position(point)
                            .highPriorityGesture(nodeDrag(node))
                            .simultaneousGesture(TapGesture(count: 2).onEnded { open(node.id) })
                            .onHover { inside in if inside { hovered = node.id } else if hovered == node.id { hovered = nil } }
                            .help(node.title)
                            .contextMenu { Button("Open") { open(node.id) }; Button("Select connections") { viewport.select(node.id) } }
                            .accessibilityLabel("\(node.id.kind.rawValue.capitalized): \(node.title)\(node.available ? "" : ", unavailable")")
                            .accessibilityHint("Select to inspect connections. Double-click to open. Drag to arrange.")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CiderColor.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gesture(canvasDrag)
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                viewport.zoom(by: Double(value.magnification / magnification)); magnification = value.magnification
            }.onEnded { _ in magnification = 1 })
            .onAppear { onSizeChanged(geometry.size) }
            .onChange(of: geometry.size) { _, size in onSizeChanged(size) }
        }
    }

    private func nodeLabel(_ node: GraphNode, emphasized: Bool) -> some View {
        Image(systemName: icon(node.id.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(viewport.selected == node.id ? CiderColor.textOnAccent : color(node.id.kind))
                .frame(width: 30, height: 30)
                .background(viewport.selected == node.id ? CiderColor.accent : CiderColor.surfaceRaised, in: Circle())
                .overlay(Circle().stroke(color(node.id.kind).opacity(0.65), lineWidth: viewport.selected == node.id ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if node.attention != nil { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(CiderColor.warning).font(.caption) }
                    else if !node.available { Image(systemName: "questionmark.circle.fill").foregroundStyle(CiderColor.textSecondary).font(.caption) }
                }
                .overlay(alignment: .top) {
                    if viewport.scale > 0.55 || viewport.selected == node.id || hovered == node.id {
                        Text(node.title).font(.caption).lineLimit(1).frame(width: 128)
                            .foregroundStyle(CiderColor.textPrimary).offset(y: 35)
                    }
                }
                .opacity(emphasized ? 1 : 0.25)
    }
    private func point(_ id: LinkedEntityID, size: CGSize) -> CGPoint? {
        guard let value = viewport.positions[id] else { return nil }
        return CGPoint(x: size.width / 2 + (value.x + viewport.offset.x) * viewport.scale, y: size.height / 2 + (value.y + viewport.offset.y) * viewport.scale)
    }
    private func icon(_ kind: LinkedEntityKind) -> String { switch kind { case .task: "checklist"; case .chat: "bubble.left.and.bubble.right"; case .note: "doc.text" } }
    private func color(_ kind: LinkedEntityKind) -> Color { switch kind { case .task: CiderColor.accent; case .chat: CiderColor.accentEnd; case .note: CiderColor.textPrimary } }
    private var canvasDrag: some Gesture {
        DragGesture().onChanged { value in
            viewport.pan(x: (value.translation.width - canvasDragTranslation.width) / viewport.scale, y: (value.translation.height - canvasDragTranslation.height) / viewport.scale)
            canvasDragTranslation = value.translation
        }.onEnded { _ in canvasDragTranslation = .zero }
    }
    private func nodeDrag(_ node: GraphNode) -> some Gesture {
        DragGesture(minimumDistance: 4).onChanged { value in
            let origin = nodeDragOrigins[node.id] ?? viewport.positions[node.id] ?? GraphPoint(x: 0, y: 0)
            nodeDragOrigins[node.id] = origin
            viewport.select(node.id)
            viewport.move(node.id, from: origin, translationX: value.translation.width, translationY: value.translation.height)
        }.onEnded { _ in nodeDragOrigins[node.id] = nil }
    }
}
