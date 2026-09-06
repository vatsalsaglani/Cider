import SwiftUI
import CiderDomain
import CiderUI

/// A durable, paged task journal. Agent output is evidence for review, never a
/// task completion or human verification signal.
struct TaskTimelineView: View {
    let taskID: UUID
    let repository: any WorkRepository
    let navigate: ((LinkedRoute) -> Void)?
    @State private var entries: [JournalEntry] = []
    @State private var nextCursor: String?
    @State private var revision: Int64?
    @State private var loading = true
    @State private var loadingMore = false
    @State private var userNote = ""
    @State private var savingNote = false
    @State private var error: String?

    init(taskID: UUID, repository: any WorkRepository, navigate: ((LinkedRoute) -> Void)? = nil) {
        self.taskID = taskID; self.repository = repository; self.navigate = navigate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved activity is evidence for review. A reported response does not mark this task done or verify any criterion.")
                .font(.caption).foregroundStyle(.secondary)
            if loading { ProgressView("Loading timeline") }
            else if entries.isEmpty {
                ContentUnavailableView("No saved timeline entries", systemImage: "clock", description: Text("Observed previews, questions, and your saved notes will appear here."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groupedEntries) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    entryView(entry).onAppear { if entry.id == entries.last?.id { loadMore() } }
                                }
                            } header: {
                                Text(group.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if nextCursor != nil {
                            Button("Load older entries") { loadMore() }
                                .buttonStyle(.bordered)
                                .disabled(loadingMore)
                            Color.clear.frame(height: 1).onAppear { loadMore() }.accessibilityHidden(true)
                        }
                        if loadingMore { ProgressView("Loading older entries") }
                    }
                }.frame(minHeight: 180, maxHeight: 420)
            }
            Divider()
            HStack {
                TextField("Add a timeline note", text: $userNote)
                Button("Save note") { appendNote() }
                    .disabled(savingNote || userNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { Text(error).font(.caption).foregroundStyle(CiderColor.failure) }
        }.task(id: taskID) { await load() }
    }

    private var groupedEntries: [TimelineGroup] {
        Dictionary(grouping: visibleEntries) { entry in
            let source = entry.chat.map { "\($0.provider.title) · \($0.sessionID.prefix(12))" } ?? "Your task"
            return TimelineGroup.Key(source: source, day: entry.occurredAt.formatted(date: .abbreviated, time: .omitted))
        }.map { TimelineGroup(key: $0.key, entries: $0.value.sorted { $0.sequence > $1.sequence }) }
            .sorted { ($0.entries.first?.occurredAt ?? .distantPast) > ($1.entries.first?.occurredAt ?? .distantPast) }
    }

    private var visibleEntries: [JournalEntry] {
        entries.filter { entry in
            entry.kind != .questionResolved || !entries.contains { question in
                question.kind == .question && question.questionID == entry.questionID
                    && question.linkID == entry.linkID && question.chat == entry.chat
            }
        }
    }

    @ViewBuilder private func entryView(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label(entry.kind)).font(.headline)
                if entry.previewOnly { Text("Preview").font(.caption).padding(.horizontal, 6).background(CiderColor.accentWash, in: Capsule()) }
                Spacer()
                Text(entry.occurredAt, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            markdown(entry.text).textSelection(.enabled)
            if entry.kind == .question, let answer = entries.first(where: {
                $0.kind == .questionResolved && $0.questionID == entry.questionID
                    && $0.linkID == entry.linkID && $0.chat == entry.chat
            }) {
                Label("Resolved \(answer.occurredAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            }
            if entry.kind == .response {
                Button("Save checkpoint to a note") { navigate?(.saveCheckpoint(entry)) }.font(.caption).disabled(navigate == nil)
                    .help(navigate == nil ? "Checkpoint saving will be connected during final integration." : "Choose a note and review the proposed append.")
            }
        }.padding(10).background(CiderColor.accentWash.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func markdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) { return Text(attributed) }
        return Text(text)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let page = try await repository.journal(JournalQuery(taskID: taskID, limit: 50))
            entries = page.items; nextCursor = page.nextCursor; revision = page.revision; error = nil
        } catch { self.error = "The timeline could not be loaded." }
    }
    private func loadMore() {
        guard !loadingMore, let nextCursor else { return }; loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let page = try await repository.journal(JournalQuery(taskID: taskID, cursor: nextCursor, limit: 50))
                if let revision, page.revision != revision { await load(); return }
                let existing = Set(entries.map(\.id)); entries += page.items.filter { !existing.contains($0.id) }
                self.nextCursor = page.nextCursor; revision = page.revision
            } catch { self.error = "Older timeline entries could not be loaded." }
        }
    }
    private func appendNote() {
        guard !savingNote else { return }
        let submitted = userNote
        let note = submitted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        savingNote = true
        Task {
            defer { savingNote = false }
            do {
                _ = try await repository.apply(WorkMutation(change: .appendUserNote(taskID: taskID, text: note)))
                if userNote == submitted { userNote = "" }
                await load()
            }
            catch { self.error = "The note was not saved. Your text is still here." }
        }
    }
    private func label(_ kind: JournalKind) -> String {
        switch kind { case .response: "Reported response"; case .question: "Question"; case .questionResolved: "Question resolved"; case .userNote: "Your note" }
    }
}

private struct TimelineGroup: Identifiable {
    struct Key: Hashable { let source: String; let day: String }
    let key: Key; let entries: [JournalEntry]
    var id: Key { key }
    var title: String { key.source + " · " + key.day }
}
