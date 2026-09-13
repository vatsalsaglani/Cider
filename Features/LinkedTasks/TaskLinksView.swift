import SwiftUI
import CiderDomain
import CiderUI

/// Relationships stay alongside the task's writing, with occasional actions in menus.
struct TaskLinksView: View {
    let detail: TaskDetail
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked notes").font(.headline)
                Text("\(detail.noteLinks.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Link an existing note") { navigate(.chooseNotes(taskID: detail.task.id)) }
                    Button("Create a linked note") { navigate(.createLinkedNote(taskID: detail.task.id)) }
                } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton).fixedSize().help("Add linked note").accessibilityLabel("Add linked note")
            }
            if detail.noteLinks.isEmpty {
                Text("Keep a plan or reference with this task.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(detail.noteLinks) { link in
                if let note = detail.notes.first(where: { $0.id == link.noteID }) {
                    Button { navigate(.note(note.id)) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text").foregroundStyle(CiderColor.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(URL(fileURLWithPath: note.relativePath).deletingPathExtension().lastPathComponent)
                                    .font(.callout.weight(.medium)).multilineTextAlignment(.leading)
                                Text(note.available ? link.role.rawValue.capitalized : "Unavailable")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.06)))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                        .contextMenu { Button("Detach note", role: .destructive) { detachNote(link) } }
                } else { Text("Unavailable note").foregroundStyle(.secondary) }
            }
            if !detail.chatLinks.isEmpty {
                Text("Chats").font(.headline).padding(.top, 12)
                ForEach(detail.chatLinks) { link in
                    if let chat = detail.chats.first(where: { $0.identity == link.chat }) {
                        Button { navigate(.chat(chat.identity)) } label: {
                            HStack {
                                Image(systemName: "bubble.left").foregroundStyle(.secondary)
                                Text(chat.title ?? "Untitled chat")
                                Spacer()
                                Text(chat.identity.provider.title).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .contextMenu { Button("Detach chat", role: .destructive) { detachChat(link) } }
                    }
                }
            }
        }
    }
    private func detachChat(_ link: TaskChatLink) {
        Task { if await model.perform(WorkMutation(change: .detachChat(linkID: link.id))) { onChanged() } }
    }
    private func detachNote(_ link: TaskNoteLink) {
        Task { if await model.perform(WorkMutation(change: .detachNote(linkID: link.id))) { onChanged() } }
    }
}
