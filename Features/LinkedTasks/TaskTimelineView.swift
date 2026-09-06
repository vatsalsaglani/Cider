import SwiftUI
import CiderDomain
import CiderUI

struct TaskTimelineView: View {
    let taskID: UUID
    let repository: any WorkRepository
    @State private var entries: [JournalEntry] = []
    @State private var loading = true
    @State private var userNote = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if loading { ProgressView("Loading timeline") }
            else if entries.isEmpty {
                ContentUnavailableView("No saved timeline entries", systemImage: "clock", description: Text("Observed previews and your saved notes will appear here."))
            } else {
                List(entries) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(label(entry.kind)).font(.headline)
                            if entry.previewOnly { Text("Preview").font(.caption).padding(.horizontal, 6).background(CiderColor.accentWash, in: Capsule()) }
                            Spacer()
                            Text(entry.occurredAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(entry.text).textSelection(.enabled)
                    }.padding(.vertical, 3)
                }
            }
            Divider()
            HStack {
                TextField("Add a timeline note", text: $userNote)
                Button("Save note") { appendNote() }.disabled(userNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { Text(error).font(.caption).foregroundStyle(CiderColor.failure) }
        }
        .task(id: taskID) { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            entries = try await repository.journal(JournalQuery(taskID: taskID, limit: 100)).items
            error = nil
        } catch { self.error = "The timeline could not be loaded." }
    }
    private func appendNote() {
        let note = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await repository.apply(WorkMutation(change: .appendUserNote(taskID: taskID, text: note)))
                userNote = ""; await load()
            } catch { self.error = "The note was not saved. Your text is still here." }
        }
    }
    private func label(_ kind: JournalKind) -> String {
        switch kind {
        case .response: "Response"
        case .question: "Question"
        case .questionResolved: "Question resolved"
        case .userNote: "Your note"
        }
    }
}
