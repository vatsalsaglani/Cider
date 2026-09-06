import SwiftUI
import CiderUI
import CiderPlatform

struct NotesView: View {
    @Bindable var notes: NotesModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Workspace").font(.headline); Spacer(); IconAction("Add folder", symbol: "folder.badge.plus") { notes.addFolder() }; IconAction("New note", symbol: "square.and.pencil") { Task { await notes.create() } } }
                ScrollView {
                    ForEach(notes.trees) { WorkspaceTreeRow(node: $0, notes: notes) }
                }
            }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12).frame(width: 220)
            Divider().opacity(0.2).padding(.horizontal, 6)
            VStack(alignment: .leading, spacing: 0) {
                if !notes.tabs.isEmpty { NoteTabStrip(notes: notes) }
                if let file = notes.selected {
                    HStack { Text(file.lastPathComponent).foregroundStyle(.secondary); Spacer(); Text(notes.status).font(.caption); IconAction("Save note", symbol: "checkmark") { Task { _ = await notes.save() } } }.padding(.horizontal, 20).padding(.vertical, 8)
                    if !notes.header.isEmpty { DisclosureGroup("Properties") { Text(notes.header).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }.padding(.horizontal, 30) }
                    MarkdownEditor(text: notes.body, document: file, changed: notes.changed, imagePasted: notes.pasteImage, openLink: notes.openLink, fragment: notes.fragment).id(notes.generation)
                } else { ContentUnavailableView("Room for your thoughts", systemImage: "doc.text", description: Text("Add a folder or create a note to begin.")).frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
        }.alert("Note needs attention", isPresented: Binding(get: { notes.error != nil }, set: { if !$0 { notes.error = nil } })) { Button("OK") { notes.error = nil } } message: { Text(notes.error ?? "") }
    }
}
