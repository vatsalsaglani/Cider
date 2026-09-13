import SwiftUI
import CiderDomain
import CiderUI

/// The linked-work entry point. App navigation is deliberately supplied by Plan 05.
struct TaskDetailView: LinkedTaskDetailFeature {
    let taskID: UUID
    let model: LinkedWorkModel
    let navigate: (LinkedRoute) -> Void
    @Bindable var session: TaskDetailSession
    var backToBoard: () -> Void
    @State private var showDeleteConfirmation = false

    init(taskID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void,
         session: TaskDetailSession, backToBoard: @escaping () -> Void = {}) {
        self.taskID = taskID; self.model = model; self.navigate = navigate
        self.session = session; self.backToBoard = backToBoard
    }

    init(taskID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void) {
        self.init(taskID: taskID, model: model, navigate: navigate, session: TaskDetailSession())
    }

    private var draft: TaskDraft? { get { session.draft } nonmutating set { session.draft = newValue } }
    private var conflict: TaskDraftConflict? { get { session.conflict } nonmutating set { session.conflict = newValue } }
    private var operationError: String? { get { session.operationError } nonmutating set { session.operationError = newValue } }
    private var section: TaskDetailSection { session.section }

    var body: some View {
        Group {
            if let detail = currentDetail, let draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        recoveryMessage
                        TaskOverviewView(draft: Binding(get: { self.draft ?? draft }, set: { self.draft = $0 }),
                                         hasChanges: (self.draft ?? draft) != TaskDraft(task: detail.task),
                                         saving: model.busy, validationMessage: validationError(for: self.draft ?? draft), onSave: save)
                            .overlay(alignment: .topTrailing) { actions(detail) }.id("overview")
                        TaskLinksView(detail: detail, model: model, navigate: navigate, onChanged: reload).id("notes")
                        DisclosureGroup("Attach a chat", isExpanded: $session.showChatPicker) {
                            TaskChatPicker(taskID: taskID, model: model, attached: detail.chatLinks, onChanged: reload)
                                .frame(height: 320).padding(.top, 14)
                        }.font(.callout).foregroundStyle(.secondary).id("chats")
                        Divider().opacity(0.25)
                        DisclosureGroup("Activity", isExpanded: $session.showActivity) {
                            TaskTimelineView(taskID: taskID, repository: model.repository, navigate: navigate, refreshRevision: detail.revision)
                                .frame(minHeight: 220).padding(.top, 14)
                        }.font(.callout).id("activity")
                    }.scrollTargetLayout()
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollPosition(id: $session.scrollAnchor, anchor: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .buttonStyle(CiderDialogButtonStyle())
                .ciderConfirmation("Delete \(detail.task.title)?",
                    message: "This removes the task and its \(detail.journalCount) saved checkpoint\(detail.journalCount == 1 ? "" : "s"). Files and chats remain.",
                    isPresented: $showDeleteConfirmation, confirmTitle: "Delete task") { delete(detail) }
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

    private func actions(_ detail: TaskDetail) -> some View {
        Menu {
            Button("Back to board", action: backToBoard)
            Button("View connections") { navigate(.graph(.task(taskID))) }
            Button("Copy saved context") { navigate(.copyContext(taskID: taskID, includeNotes: false)) }
            Button("Copy context with notes") { navigate(.copyContext(taskID: taskID, includeNotes: true)) }
            Divider()
            Button("Delete task", role: .destructive) { showDeleteConfirmation = true }
        } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
            .menuStyle(.borderlessButton).fixedSize()
            .help("Task actions").accessibilityLabel("Task actions")
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
        guard validationError(for: draft) == nil else { return }
        do {
            let saved = try draft.saveMutation()
            Task {
                if await model.perform(saved) {
                    conflict = nil; operationError = nil
                    self.draft = nil
                    await model.loadDetail(taskID)
                    seedDraftIfNeeded()
                } else {
                    let failedMessage = model.error
                    await model.loadDetail(taskID)
                    if let newer = currentDetail?.task, newer.revision != draft.originalRevision {
                        conflict = TaskDraftConflict(local: draft, saved: newer)
                        operationError = nil
                    } else {
                        operationError = failedMessage
                    }
                }
            }
        } catch { operationError = validationError(for: draft) ?? "The task could not be saved. Your draft is still here." }
    }
    @ViewBuilder private var recoveryMessage: some View {
        if let conflict {
            let latest = draft ?? conflict.local
            let comparison = conflict.comparison(using: latest)
            VStack(alignment: .leading, spacing: 8) {
                Text("This task changed while you were editing.").font(.caption).foregroundStyle(CiderColor.warning)
                DisclosureGroup("Compare saved and local versions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved revision \(conflict.saved.revision) · your draft started at revision \(conflict.local.originalRevision)")
                        if comparison.isEmpty {
                            Text("The current draft matches the saved task.")
                        } else {
                            ForEach(comparison) { row in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.field).font(.caption.weight(.semibold))
                                    comparisonValue("Saved", row.saved)
                                    comparisonValue("Your latest draft", row.local)
                                }
                            }
                        }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Use saved version") { useSavedVersion(conflict) }
                    Button("Rebase my edits") { rebase(conflict, latest: latest) }.buttonStyle(.borderedProminent)
                }
            }
        } else if let error = operationError ?? model.error {
            Text(error).font(.caption).foregroundStyle(CiderColor.warning)
        }
    }
    private func useSavedVersion(_ conflict: TaskDraftConflict) {
        draft = TaskDraft(task: conflict.saved); self.conflict = nil; operationError = nil
    }
    private func rebase(_ conflict: TaskDraftConflict, latest: TaskDraft) {
        draft = conflict.rebasedDraft(using: latest); self.conflict = nil; operationError = nil
    }
    @ViewBuilder private func comparisonValue(_ label: String, _ value: String) -> some View {
        Text("\(label): \(value)").lineLimit(6).textSelection(.enabled)
    }
    private func validationError(for draft: TaskDraft) -> String? { draft.validationMessage }
    private func delete(_ detail: TaskDetail) {
        Task {
            if await model.perform(WorkMutation(change: .deleteTask(taskID: detail.task.id))) { backToBoard() }
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
