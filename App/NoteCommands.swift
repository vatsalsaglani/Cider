import SwiftUI

struct ActiveNotesKey: FocusedValueKey { typealias Value = NotesModel }
extension FocusedValues {
    var activeNotes: NotesModel? {
        get { self[ActiveNotesKey.self] }
        set { self[ActiveNotesKey.self] = newValue }
    }
}
struct NoteCommands: Commands {
    @FocusedValue(\.activeNotes) private var notes
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { Task { await notes?.create() } }.keyboardShortcut("n").disabled(notes == nil)
            Button("Add Workspace Folder…") { notes?.addFolder() }.keyboardShortcut("o", modifiers: [.command, .shift]).disabled(notes == nil)
        }
        CommandGroup(before: .saveItem) {
            Button("Close Tab") { if let file = notes?.selected { Task { await notes?.close(file) } } }
                .keyboardShortcut("w").disabled(notes?.selected == nil)
            Button("Save Note") { Task { _ = await notes?.save() } }.keyboardShortcut("s").disabled(notes?.selected == nil)
        }
        CommandMenu("Tabs") {
            Button("Next Tab") { Task { await notes?.selectTab(offset: 1) } }
                .keyboardShortcut("]", modifiers: [.command, .shift]).disabled(notes?.tabs.isEmpty ?? true)
            Button("Previous Tab") { Task { await notes?.selectTab(offset: -1) } }
                .keyboardShortcut("[", modifiers: [.command, .shift]).disabled(notes?.tabs.isEmpty ?? true)
        }
    }
}
