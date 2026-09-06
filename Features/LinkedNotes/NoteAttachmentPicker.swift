import SwiftUI
import CiderDomain
import CiderUI

/// Explicit-root picker for existing notes or a newly created linked Markdown file.
struct NoteAttachmentPicker: View {
    let model: LinkedWorkModel
    let taskID: UUID
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var roots: [FolderReference] = []
    @State private var notes: [NoteReference] = []
    @State private var selectedRootID: UUID?
    @State private var query = ""
    @State private var title = ""
    @State private var relativeDirectory = ""
    @State private var markdown = ""
    @State private var creating = false
    @State private var pendingRegistration: NoteReference?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Attach note").font(.title2.weight(.semibold)); Spacer(); IconAction("Close", symbol: "xmark") { dismiss() } }
            Picker("Workspace folder", selection: $selectedRootID) {
                Text("Choose a folder").tag(UUID?.none)
                ForEach(roots) { root in Text(URL(fileURLWithPath: root.path).lastPathComponent).tag(Optional(root.id)) }
            }
            if let root = selectedRoot, !root.available {
                Label("This folder is unavailable. Restore or relink it before attaching files.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(CiderColor.accent)
            } else if selectedRoot != nil {
                TextField("Search notes", text: $query).onSubmit { Task { await search() } }
                if !notes.isEmpty {
                    ScrollView { VStack(alignment: .leading, spacing: 6) {
                        ForEach(notes) { note in
                            Button { Task { await attach(note) } } label: {
                                VStack(alignment: .leading) { Text(note.relativePath); Text(note.available ? "Existing Markdown note" : "Missing note").font(.caption).foregroundStyle(.secondary) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            }.buttonStyle(.plain).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10)).disabled(!note.available)
                        }
                    } }.frame(maxHeight: 170)
                }
                DisclosureGroup("Create linked note", isExpanded: $creating) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("File name", text: $title)
                        TextField("Folder path (optional)", text: $relativeDirectory)
                        TextEditor(text: $markdown).frame(minHeight: 80)
                        HStack { Spacer(); Button("Create and attach") { Task { await create() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    }.padding(.top, 6)
                }
            }
            if let note = pendingRegistration {
                Label("The file was created. Its link still needs registration.", systemImage: "arrow.clockwise")
                    .font(.caption).foregroundStyle(CiderColor.accent)
                Button("Retry registration") { Task { await registerAndAttach(note) } }
            }
            if let message { Text(message).font(.caption).foregroundStyle(CiderColor.accent) }
        }
        .padding(24).frame(width: 520)
        .task { await loadRoots() }
        .onChange(of: selectedRootID) { _, _ in Task { await search() } }
    }

    private var selectedRoot: FolderReference? { roots.first { $0.id == selectedRootID } }

    private func loadRoots() async {
        do { roots = try await model.repository.folders(); selectedRootID = roots.first?.id } catch { message = "Folders could not be loaded." }
    }

    private func search() async {
        guard let rootID = selectedRootID else { notes = []; return }
        do { notes = try await model.repository.notes(NoteQuery(rootID: rootID, search: query, limit: WorkLimits.list)).items }
        catch { message = "Notes could not be loaded." }
    }

    private func attach(_ note: NoteReference) async {
        guard await model.perform(WorkMutation(change: .attachNote(taskID: taskID, noteID: note.id, role: .context))) else { return }
        onComplete(); dismiss()
    }

    private func create() async {
        guard let root = selectedRoot, root.available else { return }
        do {
            let note = try await model.noteAccess.create(root: root, relativeDirectory: relativeDirectory, title: title, markdown: markdown)
            pendingRegistration = note
            await registerAndAttach(note)
        } catch { message = "The note could not be created in this folder." }
    }

    private func registerAndAttach(_ note: NoteReference) async {
        guard await model.perform(WorkMutation(change: .registerNote(note: note))) else { message = "The new file is safe, but registration needs a retry."; return }
        await attach(note)
        pendingRegistration = nil
    }
}
