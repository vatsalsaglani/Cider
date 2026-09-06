import SwiftUI
import CiderDomain
import CiderUI

/// Backlinks stay in the work store; this view never edits Markdown to represent a relationship.
struct NoteConnectionsView: LinkedNoteConnectionsFeature {
    let noteID: UUID
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    @State private var connections: WorkConnections?
    @State private var links: [UUID: TaskNoteLink] = [:]
    @State private var loading = false

    init(noteID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void) {
        self.noteID = noteID; self.model = model; self.navigate = navigate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Connected work").font(.title2.weight(.semibold))
                Spacer()
                IconAction("Attach this note to a TODO", symbol: "link.badge.plus") { navigate(.attachNote(noteID)) }
                IconAction("View connections", symbol: "point.3.connected.trianglepath.dotted") { navigate(.graph(.note(noteID))) }
            }
            if loading { ProgressView().controlSize(.small) }
            else if let connections, connections.tasks.isEmpty {
                ContentUnavailableView("No linked TODOs", systemImage: "link", description: Text("Attach this note to keep its context without changing the Markdown file."))
            } else if let connections {
                ForEach(connections.tasks) { task in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: links[task.id]?.role)).foregroundStyle(CiderColor.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title).font(.headline)
                            Text(roleText(links[task.id]?.role)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        IconAction("Open TODO", symbol: "arrow.up.right") { navigate(.task(task.id)) }
                        if let link = links[task.id] {
                            IconAction("Unlink note from TODO", symbol: "link.badge.minus") {
                                Task { await unlink(link) }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("Links describe related context; they do not prove that an agent read or verified this note.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: noteID) { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let result = try await model.repository.connections(.note(noteID), limit: WorkLimits.list)
            var resolved: [UUID: TaskNoteLink] = [:]
            for task in result.tasks {
                if let link = try await model.repository.detail(task.id).noteLinks.first(where: { $0.noteID == noteID }) { resolved[task.id] = link }
            }
            guard !Task.isCancelled else { return }
            connections = result; links = resolved
        } catch { connections = nil }
    }

    private func unlink(_ link: TaskNoteLink) async {
        guard await model.perform(WorkMutation(change: .detachNote(linkID: link.id))) else { return }
        await load()
    }

    private func roleText(_ role: NoteRole?) -> String {
        switch role { case .plan: "Plan"; case .evidence: "Evidence"; default: "Context" }
    }

    private func icon(for role: NoteRole?) -> String {
        switch role { case .plan: "map"; case .evidence: "checkmark.seal"; default: "doc.text" }
    }
}
