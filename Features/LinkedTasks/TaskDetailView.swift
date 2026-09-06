import SwiftUI
import CiderDomain
import CiderUI

private enum TaskDetailSection: String, CaseIterable {
    case overview = "Overview", chats = "Chats", notes = "Notes", timeline = "Timeline"
}

/// The linked-work entry point. App navigation is deliberately supplied by Plan 05.
struct TaskDetailView: LinkedTaskDetailFeature {
    let taskID: UUID
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var section: TaskDetailSection = .overview
    @State private var draft: TaskDraft?
    @State private var showDeleteConfirmation = false

    init(taskID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void) {
        self.taskID = taskID; self.model = model; self.navigate = navigate
    }

    var body: some View {
        Group {
            if let detail = currentDetail, let draft {
                VStack(alignment: .leading, spacing: 18) {
                    header(detail)
                    if let error = model.error {
                        HStack {
                            Text(error).font(.caption).foregroundStyle(CiderColor.warning)
                            Spacer()
                            Button("Reload saved task") { reload() }
                        }
                    }
                    CiderPillPicker("Task detail section", selection: $section,
                                    options: TaskDetailSection.allCases, title: { $0.rawValue })
                        .frame(maxWidth: 520)
                    sectionContent(detail: detail, draft: draft)
                }
                .padding(24)
                .alert("Delete \(detail.task.title)?", isPresented: $showDeleteConfirmation) {
                    Button("Delete task", role: .destructive) { delete(detail) }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This removes the task and its \(detail.journalCount) saved checkpoint\(detail.journalCount == 1 ? "" : "s"). Files and chats remain.")
                }
            } else if model.busy {
                ProgressView("Loading task")
            } else if model.error != nil {
                ContentUnavailableView("Task unavailable", systemImage: "exclamationmark.triangle", description: Text(model.error ?? "The task could not be loaded."))
            } else {
                ContentUnavailableView("Task not found", systemImage: "checklist")
            }
        }
        .task(id: taskID) { await load() }
        .onChange(of: currentDetail?.revision) { _, _ in seedDraftIfNeeded() }
    }

    @ViewBuilder private func header(_ detail: TaskDetail) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.task.title).font(.title2.weight(.semibold))
                Text("\(detail.chatLinks.count) contributor\(detail.chatLinks.count == 1 ? "" : "s") · \(detail.noteLinks.count) note\(detail.noteLinks.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Back to board") { dismiss() }
            Menu {
                Button("Delete task", role: .destructive) { showDeleteConfirmation = true }
            } label: { Image(systemName: "ellipsis.circle") }
            .help("Task actions").accessibilityLabel("Task actions")
        }
    }

    @ViewBuilder private func sectionContent(detail: TaskDetail, draft: TaskDraft) -> some View {
        switch section {
        case .overview:
            TaskOverviewView(draft: Binding(get: { self.draft ?? draft }, set: { self.draft = $0 }), saving: model.busy, onSave: save)
        case .chats:
            TaskChatPicker(taskID: taskID, model: model, attached: detail.chatLinks, onChanged: reload)
        case .notes:
            TaskLinksView(detail: detail, model: model, navigate: navigate, onChanged: reload)
        case .timeline:
            TaskTimelineView(taskID: taskID, repository: model.repository)
        }
    }

    private var currentDetail: TaskDetail? {
        guard model.selectedDetail?.task.id == taskID else { return nil }
        return model.selectedDetail
    }
    private func load() async { await model.loadDetail(taskID); seedDraftIfNeeded() }
    private func reload() { Task { await model.loadDetail(taskID) } }
    private func seedDraftIfNeeded() {
        guard let task = currentDetail?.task else { return }
        if draft == nil || draft?.taskID != task.id { draft = TaskDraft(task: task) }
    }
    private func save() {
        guard let draft else { return }
        do {
            let saved = try draft.saveMutation()
            Task {
                if await model.perform(saved) {
                    self.draft = nil
                    await model.loadDetail(taskID)
                    seedDraftIfNeeded()
                }
            }
        } catch { /* Inline validation uses the same repository contract. Keep the draft intact. */ }
    }
    private func delete(_ detail: TaskDetail) {
        Task {
            if await model.perform(WorkMutation(change: .deleteTask(taskID: detail.task.id))) { dismiss() }
        }
    }
}

#Preview("Linked task detail") {
    let repository = TaskDetailPreviewRepository()
    let model = LinkedWorkModel(repository: repository, noteAccess: TaskDetailPreviewNotes())
    model.updateAvailableChats(TaskDetailPreviewRepository.chats)
    return TaskDetailView(taskID: TaskDetailPreviewRepository.taskID, model: model, navigate: { _ in })
        .frame(width: 760, height: 620)
}

/// Preview-only protocol fake. It holds no files, agent output, or user state.
private actor TaskDetailPreviewRepository: WorkRepository {
    nonisolated static let taskID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    nonisolated static let chat = ChatReference(
        identity: ChatIdentity(hostID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, provider: .codex, sessionID: "preview-session-0001"),
        title: "Implement linked task detail", directory: "/Synthetic/linked-work",
        observedAt: Date(timeIntervalSinceReferenceDate: 0), currentTurnID: "preview-turn", execution: .working)
    nonisolated static let chats = [chat]
    private let task = WorkTask(id: taskID, title: "Review linked work", descriptionMarkdown: "Keep the task relationship explicit.", status: .inProgress,
                                criteria: [WorkCriterion(text: "Use stable chat identities")], revision: 1)

    func info() -> WorkStoreInfo { WorkStoreInfo(revision: 1, hostID: Self.chat.identity.hostID) }
    func tasks(_ query: TaskQuery) -> WorkPage<WorkTask> { WorkPage(items: [task], revision: 1) }
    func detail(_ id: UUID) throws -> TaskDetail {
        guard id == task.id else { throw WorkStoreError.notFound }
        let link = TaskChatLink(taskID: task.id, chat: Self.chat.identity, role: "Implementation", startedAt: Date(timeIntervalSinceReferenceDate: 0), initialTurnID: Self.chat.currentTurnID, revision: 1)
        return TaskDetail(task: task, chats: Self.chats, chatLinks: [link], notes: [], noteLinks: [], journalCount: 0, revision: 1)
    }
    func folders() -> [FolderReference] { [] }
    func note(_ id: UUID) throws -> NoteReference { throw WorkStoreError.notFound }
    func notes(_ query: NoteQuery) -> WorkPage<NoteReference> { WorkPage(items: [], revision: 1) }
    func connections(_ entity: LinkedEntityID, limit: Int) -> WorkConnections { WorkConnections(entity: entity, tasks: [], chats: [], notes: [], edges: [], revision: 1) }
    func journal(_ query: JournalQuery) -> WorkPage<JournalEntry> { WorkPage(items: [], revision: 1) }
    func graph(_ query: GraphQuery) -> GraphSnapshot { GraphSnapshot(revision: 1, nodes: [], edges: []) }
    func attribution(chats: [ChatIdentity], eventIDs: [UUID]) -> AttributionSnapshot { AttributionSnapshot(revision: 1, links: [], episodes: [], processedEventIDs: []) }
    func notchPreferences() -> NotchPreferences { NotchPreferences() }
    func apply(_ mutation: WorkMutation) -> MutationReceipt { MutationReceipt(revision: 2, entity: .task(Self.taskID)) }
    func appendJournal(_ batch: JournalBatch) -> JournalReceipt { JournalReceipt(revision: 2, inserted: 0, duplicate: 0) }
}

private actor TaskDetailPreviewNotes: LinkedNoteAccess {
    func resolve(_ note: NoteReference, root: FolderReference) throws -> URL { throw WorkStoreError.notImplemented }
    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) throws -> NoteFileSnapshot { throw WorkStoreError.notImplemented }
    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) throws -> NoteReference { throw WorkStoreError.notImplemented }
    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) throws -> NoteAppendProposal { throw WorkStoreError.notImplemented }
    func applyAppend(_ proposal: NoteAppendProposal) throws -> NoteFileSnapshot { throw WorkStoreError.notImplemented }
    func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) throws -> [NoteDocumentLink] { throw WorkStoreError.notImplemented }
}
