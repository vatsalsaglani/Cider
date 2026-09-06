import SwiftUI
import CiderDomain
import CiderUI

struct TaskChatPicker: View {
    let taskID: UUID
    let model: LinkedWorkModel
    let attached: [TaskChatLink]
    let onChanged: () -> Void
    @State private var search = ""
    @State private var role = ""
    @State private var selectedID: ChatIdentity?
    @State private var includeCurrentTurn = false

    private var candidates: [ChatReference] {
        model.availableChats.filter { chat in
            attached.allSatisfy { $0.chat != chat.identity }
                && (search.isEmpty || [chat.title ?? "", chat.directory, chat.identity.provider.title]
                    .contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
    private var selected: ChatReference? { candidates.first { $0.identity == selectedID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Attach an observed chat").font(.headline)
            Text("A new attachment starts with upcoming observed turns. It never resumes, forks, or messages a chat.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Search title, workspace, or provider", text: $search)
            if candidates.isEmpty {
                ContentUnavailableView("No matching observed chats", systemImage: "bubble.left.and.bubble.right", description: Text("Refresh Activity or change the search."))
            } else {
                List(candidates, id: \.identity, selection: $selectedID) { chat in
                    ChatRow(chat: chat, duplicateTitle: duplicateTitle(chat))
                        .tag(chat.identity)
                }.frame(minHeight: 180)
            }
            if let selected {
                TextField("Contributor role (optional)", text: $role)
                if let turn = selected.currentTurnID, !turn.isEmpty {
                    Toggle("Include current observed turn", isOn: $includeCurrentTurn)
                    Text("Only this exact observed turn will be included.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Attach contributor") {
                    let currentTurn = includeCurrentTurn ? selected.currentTurnID : nil
                    Task {
                        let saved = await model.perform(WorkMutation(change: .attachChat(
                            taskID: taskID, chat: selected,
                            role: role.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                            initialTurnID: currentTurn)))
                        if saved { onChanged() }
                    }
                }
                .buttonStyle(.borderedProminent).tint(CiderColor.accent)
            }
        }
        .onChange(of: selectedID) { _, _ in includeCurrentTurn = false }
    }

    private func duplicateTitle(_ chat: ChatReference) -> Bool {
        guard let title = chat.title, !title.isEmpty else { return false }
        return model.availableChats.filter { $0.title == title }.count > 1
    }
}

private struct ChatRow: View {
    let chat: ChatReference
    let duplicateTitle: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(chat.title?.nilIfEmpty ?? "Untitled chat").font(.headline)
                if duplicateTitle { Text(String(chat.identity.sessionID.suffix(8))).font(.caption.monospaced()).foregroundStyle(.secondary) }
                Spacer()
                Text(chat.identity.provider.title).font(.caption).foregroundStyle(.secondary)
            }
            Text(chat.directory).lineLimit(1).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(chat.origin?.name ?? "Source app unavailable")
                Text("·")
                if let observedAt = chat.observedAt { Text("Last seen \(observedAt, style: .relative)") }
                else { Text("Last seen unknown") }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
