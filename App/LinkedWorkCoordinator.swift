import Foundation
import Observation
import CiderDomain
import CiderData
import CiderUI

/// One application-owned repository and editor session serve workspace and HUD routes.
@MainActor @Observable
final class LinkedWorkCoordinator {
    let notes: NotesModel
    init(notes: NotesModel = NotesModel()) { self.notes = notes }
    private(set) var model: LinkedWorkModel?
    private(set) var revision: Int64 = 0
    @ObservationIgnored var refreshBoard: (() async -> Void)?
    private(set) var hostID: UUID?
    var checkpointEntry: JournalEntry?
    var checkpointProposal: NoteAppendProposal?
    private(set) var appending = false
    private var appendReceipt: NoteFileSnapshot?
    var selectedTask: UUID?
    var attachmentTask: UUID?
    var connectionNote: UUID?
    var pendingChat: ChatReference?
    var pendingNote: UUID?
    var linking = false
    var draftTitle = ""
    var draftDescription = ""
    var createDraft = false
    private var deferredRoute: LinkedRoute?
    var error: String?
    @ObservationIgnored var showNotes: (() -> Void)?
    @ObservationIgnored var openChat: ((ChatIdentity) -> Void)?
    @ObservationIgnored var journalIngestor: (any WorkJournalIngesting)?
    private let noteAccess = LinkedNoteService()

    func start(repository: any WorkRepository) async throws {
        guard model == nil else { return }
        let info = try await repository.info()
        hostID = info.hostID; revision = info.revision
        model = LinkedWorkModel(repository: repository, noteAccess: noteAccess)
        notes.onRename = { [weak self] url, name in await self?.renameNote(url, name: name) }
        notes.onCreateTask = { [weak self] url in
            guard let self, await self.notes.save() else { return }
            do {
                let note = try await self.registerNote(url)
                self.route(.createTaskFromNote(noteID: note.id, excerpt: nil))
                self.draftTitle = url.deletingPathExtension().lastPathComponent
            } catch { self.error = "The note could not be connected. Your writing remains open." }
        }
        notes.onConnections = { [weak self] url in
            guard let self, await self.notes.save() else { return }
            do { self.connectionNote = try await self.registerNote(url).id }
            catch { self.error = "Connections could not be opened for this note." }
        }
        notes.onFileOpened = { [weak self] url in await self?.register(url) }
        notes.onFileSaved = { [weak self] url in await self?.register(url, replaced: true) }
        try await syncFolders()
        notes.onScan = { [weak self] urls in await self?.indexNotes(urls) }
        await indexNotes(notes.files)
    }
    @ObservationIgnored private var folderSync: Task<Void, Error>?
    func syncFolders() async throws {
        if let operation = folderSync { try await operation.value; return }
        let operation = Task<Void, Error> { try await synchronizeFolders() }
        folderSync = operation
        defer { folderSync = nil }
        try await operation.value
    }
    private func synchronizeFolders() async throws {
        guard let model else { return }
        let saved = try await model.repository.folders()
        for folder in saved {
            let included = notes.folders.contains { $0.standardizedFileURL.path == folder.path }
            if included != folder.available {
                _ = try await model.repository.apply(WorkMutation(change: .setFolderAvailable(rootID: folder.id, available: included)))
            }
        }
        for url in notes.folders {
            let path = url.standardizedFileURL.path
            if !saved.contains(where: { $0.path == path }) {
                _ = try await model.repository.apply(WorkMutation(change: .registerFolder(folder: FolderReference(path: path))))
            }
        }
    }
    private var indexing = false
    private func indexNotes(_ urls: [URL]) async {
        guard let model, !indexing else { return }
        indexing = true
        defer { indexing = false }
        do {
            try await syncFolders()
            let roots = try await model.repository.folders()
            var known: [NoteReference] = []
            var cursor: String?
            repeat {
                let page = try await model.repository.notes(NoteQuery(cursor: cursor, limit: WorkLimits.list))
                known += page.items; cursor = page.nextCursor
            } while cursor != nil
            for url in urls.prefix(2000) {
                guard let root = roots.filter({ url.path.hasPrefix($0.path + "/") }).max(by: { $0.path.count < $1.path.count }) else { continue }
                let path = String(url.path.dropFirst(root.path.count + 1))
                if known.contains(where: { $0.rootID == root.id && $0.relativePath == path }) { continue }
                let note = NoteReference(rootID: root.id, relativePath: path)
                // Resolve checks containment without loading document bodies during indexing.
                _ = try await noteAccess.resolve(note, root: root)
                _ = try await model.repository.apply(WorkMutation(change: .registerNote(note: note)))
                known.append(note)
            }
        } catch { self.error = "Some note connections could not be indexed. Your files remain available in Notes." }
    }
    func observe(_ sessions: [TrackedSession]) async {
        guard let model, let hostID else { return }
        let chats = sessions.filter { $0.parent == nil }.map { row in
            ChatReference(identity: ChatIdentity(hostID: hostID, provider: row.provider, sessionID: row.session),
                title: row.title, directory: row.directory, origin: row.history.last(where: { $0.origin != nil })?.origin,
                observedAt: row.updated, currentTurnID: row.turn, execution: row.execution,
                attention: row.questions.isEmpty ? row.attention : "Input requested")
        }
        model.updateAvailableChats(chats)
        do { _ = try await model.repository.apply(WorkMutation(change: .observeChats(chats: chats))); await refresh() }
        catch { self.error = "Linked activity could not be refreshed. Saved links have been kept." }
    }
    func refresh() async {
        if let info = try? await model?.repository.info(), revision != info.revision {
            revision = info.revision
            await refreshBoard?()
        }
    }
    func reference(_ row: TrackedSession) -> ChatReference? {
        model?.availableChats.first { $0.identity.provider == row.provider && $0.identity.sessionID == row.session }
    }
    func resumeNavigation() {
        guard let next = deferredRoute else { return }
        deferredRoute = nil
        route(next)
    }
    func route(_ route: LinkedRoute) {
        if connectionNote != nil {
            switch route {
            case .task, .attachNote, .createTaskFromNote:
                deferredRoute = route; connectionNote = nil; return
            default: break
            }
        }
        switch route {
        case .task(let id): selectedTask = id
        case .chat(let identity): openChat?(identity)
        case .note(let id): Task { await openNote(id) }
        case .chooseNotes(let id), .createLinkedNote(let id): attachmentTask = id
        case .saveCheckpoint(let entry): Task { await previewCheckpoint(entry) }
        case .attachChat(let chat): pendingChat = chat; pendingNote = nil; linking = true
        case .attachNote(let id): pendingNote = id; pendingChat = nil; linking = true
        case .createTaskFromChat(let chat):
            guard createdDraftID == nil else { createDraft = true; return }
            pendingChat = chat; pendingNote = nil; draftTitle = chat.title ?? ""; draftDescription = ""; createDraft = true
        case .createTaskFromNote(let id, let excerpt):
            guard createdDraftID == nil else { createDraft = true; return }
            pendingNote = id; pendingChat = nil; draftTitle = ""; draftDescription = excerpt ?? ""; createDraft = true
        default: error = "This connection action is not available yet."
        }
    }
    func attach(to taskID: UUID) async -> Bool {
        guard !linkingBusy else { return false }
        linkingBusy = true
        defer { linkingBusy = false }
        return await performAttachment(to: taskID)
    }
    private func performAttachment(to taskID: UUID) async -> Bool {
        guard let model else { return false }
        do {
            if let chat = pendingChat {
                _ = try await model.repository.apply(WorkMutation(change: .attachChat(taskID: taskID, chat: chat, role: nil, initialTurnID: nil)))
            }
            if let note = pendingNote {
                _ = try await model.repository.apply(WorkMutation(change: .attachNote(taskID: taskID, noteID: note, role: .context)))
            }
            if linking || createDraft { deferredRoute = .task(taskID) }
            else { selectedTask = taskID }
            linking = false; createDraft = false
            pendingChat = nil; pendingNote = nil
            return true
        } catch { self.error = "The connection could not be saved. Please retry."; return false }
    }
    private var createdDraftID: UUID?
    private(set) var linkingBusy = false
    func createAndAttach() async {
        guard let model, !linkingBusy else { return }
        linkingBusy = true
        defer { linkingBusy = false }
        do {
            // A failed attachment retry reuses the created task, never creates a duplicate.
            if createdDraftID == nil {
                let task = WorkTask(title: draftTitle, descriptionMarkdown: draftDescription)
                _ = try await model.repository.apply(WorkMutation(change: .saveTask(task: task)))
                createdDraftID = task.id
            }
            if let id = createdDraftID, await performAttachment(to: id) { createdDraftID = nil }
        } catch { self.error = "The task could not be saved. Your draft is still here." }
    }
    func previewCheckpoint(_ entry: JournalEntry) async {
        guard let model, let url = notes.selected, await notes.save() else {
            error = "Open a destination note before saving a checkpoint."; return
        }
        do {
            let note = try await registerNote(url)
            guard let root = try await model.repository.folders().first(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
            let source = entry.chat.map { "\($0.provider.title) · \($0.sessionID)" } ?? "User note"
            let markdown = "\n\n## Checkpoint\n\n" + source + " · " + entry.occurredAt.formatted() + "\n\n" + entry.text + "\n"
            checkpointProposal = try await noteAccess.previewAppend(note: note, root: root, markdown: markdown)
            checkpointEntry = entry; appendReceipt = nil
        } catch { self.error = "The checkpoint preview could not be prepared. Your note remains unchanged." }
    }
    func cancelCheckpoint() {
        guard !appending else { return }
        guard appendReceipt == nil else {
            error = "The checkpoint has been written. Retry saving its connection before closing."; return
        }
        checkpointProposal = nil; checkpointEntry = nil
    }
    func confirmCheckpoint() async {
        guard !appending else { return }
        appending = true
        defer { appending = false }
        guard let model, let proposal = checkpointProposal else { return }
        guard await notes.save() else { return }
        do {
            if appendReceipt == nil { appendReceipt = try await noteAccess.applyAppend(proposal) }
            guard let receipt = appendReceipt else { return }
            var note = proposal.note
            note.fileIdentity = receipt.fileIdentity; note.modifiedAt = receipt.modifiedAt
            _ = try await model.repository.apply(WorkMutation(change: .registerNote(note: note)))
            checkpointProposal = nil; checkpointEntry = nil; appendReceipt = nil
            await openNote(note.id)
        } catch { self.error = appendReceipt == nil
            ? "The note changed or could not be saved. Review it before retrying the checkpoint."
            : "The checkpoint was written, but its connection needs saving. Retry to finish without adding it twice." }
    }
    func register(_ url: URL, replaced: Bool = false) async {
        do { _ = try await registerNote(url, replaced: replaced) }
        catch { self.error = "The note is open, but its connections could not be refreshed." }
    }
    @discardableResult
    func registerNote(_ url: URL, replaced: Bool = false) async throws -> NoteReference {
        guard let model else { throw WorkStoreError.unavailable }
        try await syncFolders()
        let roots = try await model.repository.folders()
        guard let root = roots.filter({ url.standardizedFileURL.path.hasPrefix($0.path + "/") })
            .max(by: { $0.path.count < $1.path.count }) else { throw WorkStoreError.outsideRoot }
        let (canonicalRoot, canonical) = try await AgentIO.run {
            (URL(fileURLWithPath: root.path).resolvingSymlinksInPath().path, url.resolvingSymlinksInPath().path)
        }
        guard canonical.hasPrefix(canonicalRoot + "/") else { throw WorkStoreError.outsideRoot }
        let path = String(canonical.dropFirst(canonicalRoot.count + 1))
        var cursor: String?
        var reference: NoteReference?
        repeat {
            let page = try await model.repository.notes(NoteQuery(rootID: root.id, cursor: cursor, limit: WorkLimits.list))
            reference = page.items.first { $0.relativePath == path }
            cursor = page.nextCursor
        } while reference == nil && cursor != nil
        var note = reference ?? NoteReference(rootID: root.id, relativePath: path)
        // Only our successful coordinated save can explicitly adopt a replacement inode.
        if replaced { note.fileIdentity = nil }
        let snapshot = try await noteAccess.read(note, root: root, maxBytes: WorkLimits.noteBytes)
        note.fileIdentity = snapshot.fileIdentity; note.modifiedAt = snapshot.modifiedAt
        if reference != note {
            _ = try await model.repository.apply(WorkMutation(change: .registerNote(note: note)))
        }
        var known: [NoteReference] = []
        cursor = nil
        repeat {
            let page = try await model.repository.notes(NoteQuery(rootID: root.id, cursor: cursor, limit: WorkLimits.list))
            known += page.items; cursor = page.nextCursor
        } while cursor != nil
        let links = try await noteAccess.documentLinks(note: note, root: root, knownNotes: known, maxBytes: WorkLimits.noteBytes)
        _ = try await model.repository.apply(WorkMutation(change: .replaceDocumentLinks(sourceNoteID: note.id, links: links)))
        return note
    }
    private var renaming = false
    func renameNote(_ url: URL, name: String) async {
        guard let model, !renaming else { return }
        renaming = true
        defer { renaming = false }
        guard await notes.save() else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 180, !trimmed.contains("/"), !trimmed.contains("\\"),
              trimmed != ".", trimmed != ".." else { error = "Choose a note filename without folders."; return }
        let filename = ["md", "markdown"].contains(URL(fileURLWithPath: trimmed).pathExtension.lowercased()) ? trimmed : trimmed + ".md"
        do {
            var note = try await registerNote(url)
            guard let root = try await model.repository.folders().first(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
            let source = try await noteAccess.resolve(note, root: root)
            let target = source.deletingLastPathComponent().appending(path: filename)
            guard source != target else { return }
            try await Self.moveNote(source, to: target)
            let parent = (note.relativePath as NSString).deletingLastPathComponent
            note.relativePath = parent.isEmpty ? filename : parent + "/" + filename
            do { _ = try await model.repository.apply(WorkMutation(change: .registerNote(note: note))) }
            catch {
                // Restore the original name if the metadata transaction cannot commit.
                do { try await Self.moveNote(target, to: source) }
                catch {
                    notes.didRename(url, to: target)
                    self.error = "The file was renamed, but its connection could not be updated or restored. The note remains open at its new name."; return
                }
                throw error
            }
            notes.didRename(url, to: target)
            await refresh()
        } catch { self.error = "The note could not be renamed. Choose a different filename or retry." }
    }
    private static func moveNote(_ source: URL, to target: URL) async throws {
        try await AgentIO.run {
            var coordinationError: NSError?
            var operationError: Error?
            NSFileCoordinator().coordinate(writingItemAt: source, options: .forMoving,
                writingItemAt: target, options: .forReplacing, error: &coordinationError) { from, to in
                do { try FileManager.default.moveItem(at: from, to: to) }
                catch { operationError = error }
            }
            if let failure = coordinationError ?? operationError as NSError? { throw failure }
        }
    }
    func showConnections() async {
        guard let url = notes.selected, await notes.save() else { return }
        do { connectionNote = try await registerNote(url).id }
        catch { self.error = "Connections could not be opened for this note." }
    }
    func openNote(_ id: UUID) async {
        guard let model, await notes.save() else { return }
        do {
            let note = try await model.repository.note(id)
            guard let root = try await model.repository.folders().first(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
            let url = try await noteAccess.resolve(note, root: root)
            await notes.open(url)
            if notes.selected == url { selectedTask = nil; connectionNote = nil; showNotes?() }
        } catch { self.error = "The linked note is unavailable. Its original connection has been kept." }
    }
}
