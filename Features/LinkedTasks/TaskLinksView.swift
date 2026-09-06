import SwiftUI
import CiderDomain
import CiderUI

struct TaskLinksView: View {
    let detail: TaskDetail
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    let onChanged: () -> Void

    var body: some View {
        List {
            Section("Contributors") {
                if detail.chatLinks.isEmpty {
                    Text("No chats attached.").foregroundStyle(.secondary)
                } else {
                    ForEach(detail.chatLinks) { link in
                        if let chat = detail.chats.first(where: { $0.identity == link.chat }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chat.title?.isEmpty == false ? chat.title! : "Untitled chat")
                                    Text("\(chat.identity.provider.title) · \(chat.origin?.name ?? "Source app unavailable") · \(chat.directory)")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(link.role?.isEmpty == false ? link.role! : "Contributor")
                                        if duplicateTitle(chat) { Text("· \(String(chat.identity.sessionID.suffix(8)))").monospaced() }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Open") { navigate(.chat(chat.identity)) }
                                Button("Detach", role: .destructive) { detachChat(link) }
                            }
                        } else {
                            Text("Unavailable chat \(String(link.chat.sessionID.suffix(8)))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Notes") {
                if detail.noteLinks.isEmpty {
                    Text("No notes attached.").foregroundStyle(.secondary)
                } else {
                    ForEach(detail.noteLinks) { link in
                        if let note = detail.notes.first(where: { $0.id == link.noteID }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.relativePath)
                                    Text(note.available ? link.role.rawValue.capitalized : "Unavailable · \(link.role.rawValue.capitalized)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Open") { navigate(.note(note.id)) }
                                Button("Detach", role: .destructive) { detachNote(link) }
                            }
                        } else {
                            Text("Unavailable note").foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Attach note") { navigate(.chooseNotes(taskID: detail.task.id)) }
                Button("Create linked note") { navigate(.createLinkedNote(taskID: detail.task.id)) }
            }
            Section {
                Button("View connections") { navigate(.graph(.task(detail.task.id))) }
            }
        }
    }

    private func detachChat(_ link: TaskChatLink) {
        Task { if await model.perform(WorkMutation(change: .detachChat(linkID: link.id))) { onChanged() } }
    }
    private func duplicateTitle(_ chat: ChatReference) -> Bool {
        guard let title = chat.title, !title.isEmpty else { return false }
        return detail.chats.filter { $0.title == title }.count > 1
    }
    private func detachNote(_ link: TaskNoteLink) {
        Task { if await model.perform(WorkMutation(change: .detachNote(linkID: link.id))) { onChanged() } }
    }
}
