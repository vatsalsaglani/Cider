import SwiftUI
import CiderUI

struct NoteRenameDialog: View {
    @Bindable var notes: NotesModel
    @FocusState private var editing: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CiderDialogHeading("Rename note", symbol: "square.and.pencil")
            Text("Related task connections will keep following this note.")
                .foregroundStyle(CiderColor.textSecondary)
            TextField("Note name", text: $notes.renameDraft).textFieldStyle(.plain)
                .padding(12).background(CiderColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .focused($editing)
            HStack {
                Button("Cancel") { notes.renameTarget = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Rename") { notes.confirmRename() }
                    .buttonStyle(CiderDialogButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(notes.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 460).ciderDialog().onAppear { editing = true }
    }
}
