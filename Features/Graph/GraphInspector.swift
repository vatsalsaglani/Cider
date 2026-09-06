import SwiftUI
import CiderDomain
import CiderUI

struct GraphInspector: View {
    let snapshot: GraphSnapshot
    @Binding var viewport: GraphViewport
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    let reload: () -> Void
    let workspace: String

    var body: some View {
        List(selection: selection) {
            if let error = model.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CiderColor.warning)
                }
            }
            Section("Connection list") {
                ForEach(snapshot.nodes) { node in
                    HStack {
                        Image(systemName: icon(node.id.kind)).foregroundStyle(CiderColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title).lineLimit(1)
                            Text(metadata(node)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button("Open") { open(node.id) }.buttonStyle(.borderless)
                        Button("View connections") { navigate(.graph(node.id)) }.buttonStyle(.borderless)
                    }
                    .tag(node.id)
                    .contextMenu { contextActions(for: node.id) }
                    .accessibilityElement(children: .contain)
                }
            }
            if let node = snapshot.nodes.first(where: { $0.id == viewport.selected }) {
                Section("Selected") {
                    LabeledContent("Title", value: node.title)
                    LabeledContent("Workspace", value: workspace)
                    if let subtitle = node.subtitle, !subtitle.isEmpty { LabeledContent("Details", value: subtitle) }
                    LabeledContent("Status", value: status(node))
                    LabeledContent("Connections", value: "\(snapshot.edges.filter { $0.source == node.id || $0.target == node.id }.count)")
                    Button("Open selected") { open(node.id) }
                }
            }
        }
        .accessibilityLabel("Graph connection list")
    }

    private var selection: Binding<LinkedEntityID?> { Binding { viewport.selected } set: { viewport.select($0) } }
    @ViewBuilder private func contextActions(for id: LinkedEntityID) -> some View {
        Button("Open") { open(id) }
        Button("View connections") { navigate(.graph(id)) }
        let edges = snapshot.edges.filter { $0.source == id || $0.target == id }
        ForEach(edges) { edge in
            if edge.kind == .contributes || [.noteContext, .noteEvidence, .notePlan].contains(edge.kind) {
                Button("Unlink \(edge.kind == .contributes ? "chat" : "note")", role: .destructive) { unlink(edge) }
            }
        }
    }
    private func unlink(_ edge: GraphEdge) {
        let change: WorkChange? = switch edge.kind {
        case .contributes: .detachChat(linkID: edge.id)
        case .noteContext, .noteEvidence, .notePlan: .detachNote(linkID: edge.id)
        case .documentLink: nil
        }
        guard let change else { return }
        Task { if await model.perform(WorkMutation(change: change)) { reload() } }
    }
    private func open(_ id: LinkedEntityID) { switch id { case .task(let id): navigate(.task(id)); case .note(let id): navigate(.note(id)); case .chat(let id): navigate(.chat(id)) } }
    private func icon(_ kind: LinkedEntityKind) -> String { switch kind { case .task: "checklist"; case .chat: "bubble.left.and.bubble.right"; case .note: "doc.text" } }
    private func status(_ node: GraphNode) -> String { if let status = node.taskStatus { return status.rawValue }; if let execution = node.execution { return execution.rawValue }; return node.available ? "Available" : "Unavailable" }
    private func metadata(_ node: GraphNode) -> String { [node.id.kind.rawValue.capitalized, status(node), node.available ? nil : "Unavailable"].compactMap { $0 }.joined(separator: " · ") }
}
