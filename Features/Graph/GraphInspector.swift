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
            if let node = snapshot.nodes.first(where: { $0.id == viewport.selected }) {
                Section("Selected") {
                    Text(node.title).font(.headline).textSelection(.enabled)
                    if let subtitle = node.subtitle, !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                    Text(status(node)).font(.caption).foregroundStyle(.secondary)
                    if let attention = node.attention { Label(attention, systemImage: "exclamationmark.bubble").foregroundStyle(CiderColor.warning) }
                    HStack {
                        Button("Open") { open(node.id) }
                        Button("Focus graph") { navigate(.graph(node.id)) }
                    }
                    if case .note(let id) = node.id { Button("Link to a task") { navigate(.attachNote(id)) } }
                }
                Section("Connections") {
                    let incident = snapshot.edges.filter { $0.source == node.id || $0.target == node.id }
                    if incident.isEmpty { Text("No connections yet. Link this work to a task or another note.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(incident) { edge in
                        let target = edge.source == node.id ? edge.target : edge.source
                        if let neighbor = snapshot.nodes.first(where: { $0.id == target }) {
                            Button { viewport.select(target) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Label(neighbor.title, systemImage: icon(target.kind)).lineLimit(2)
                                    Text(edgeLabel(edge.kind)).font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Section("All work · \(snapshot.nodes.count)") {
                ForEach(snapshot.nodes) { node in
                    HStack {
                        Image(systemName: icon(node.id.kind)).foregroundStyle(CiderColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title).lineLimit(1)
                            Text(metadata(node)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .tag(node.id)
                    .contextMenu { contextActions(for: node.id) }
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityLabel("Graph connection list")
    }

    private func edgeLabel(_ kind: GraphEdgeKind) -> String {
        switch kind { case .contributes: "Contributes to task"; case .documentLink: "Note link"; case .noteContext: "Task context"; case .noteEvidence: "Task evidence"; case .notePlan: "Task plan" }
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
