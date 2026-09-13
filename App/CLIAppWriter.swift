import Foundation
import CiderDomain
import CiderData

/// Executed by the inbox one command at a time against the app's ready repository.
@MainActor final class CLIAppWriter {
    let app: AppModel
    let linked: LinkedWorkCoordinator
    init(app: AppModel, linked: LinkedWorkCoordinator) { self.app = app; self.linked = linked }

    func execute(_ command: CLIWriteCommand) async -> CLIWriteReply {
        var reply = CLIWriteReply()
        do {
            try command.validate()
            guard app.ready, let repository = app.repository else { throw WorkStoreError.unavailable }
            switch command.operation {
            case .createTask:
                let task = WorkTask(title: command.title!, descriptionMarkdown: command.markdown ?? "",
                                    plannedDay: command.day ?? LocalDay(), status: command.status ?? .planned,
                                    sortOrder: (app.workTasks.map(\.sortOrder).max() ?? -1) + 1)
                _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
                reply.task = try await repository.detail(task.id).task
            case .updateTask:
                var task = try await repository.detail(command.taskID!).task
                guard task.revision == command.expectedRevision else { throw WorkStoreError.conflict }
                if let title = command.title { task.title = title }
                if let text = command.markdown { task.descriptionMarkdown = text }
                if let day = command.day { task.plannedDay = day }
                if let status = command.status { task.status = status }
                _ = try await repository.apply(WorkMutation(change: .saveTask(task: task)))
                reply.task = try await repository.detail(task.id).task
            case .journalNote:
                _ = try await repository.apply(WorkMutation(change: .appendUserNote(taskID: command.taskID!, text: command.markdown!)))
            case .linkNote:
                _ = try await repository.apply(WorkMutation(change: .attachNote(taskID: command.taskID!, noteID: command.noteID!, role: command.role!)))
            case .createNote:
                let root: FolderReference
                if let id = command.rootID {
                    guard let chosen = try await repository.folders().first(where: { $0.id == id && $0.available }) else { throw WorkStoreError.notFound }
                    root = chosen
                } else {
                    let folder = try await linked.notes.ciderFolderForCLI()
                    try await linked.syncFolders()
                    guard let chosen = try await repository.folders().first(where: { $0.path == folder.path && $0.available }) else { throw WorkStoreError.unavailable }
                    root = chosen
                }
                let note = try await linked.noteAccess.create(root: root, relativeDirectory: "", title: command.title!, markdown: command.markdown ?? "")
                let url = try await linked.noteAccess.resolve(note, root: root)
                reply.path = url.path; reply.partialWrite = true
                reply.note = try await linked.registerNote(url)
                reply.sha256 = try await linked.noteAccess.read(reply.note!, root: root, maxBytes: WorkLimits.noteBytes).sha256
                reply.partialWrite = false
                linked.notes.scan()
            case .replaceNote, .appendNote:
                let note = try await repository.note(command.noteID!)
                guard let root = try await repository.folders().first(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
                let url = try await linked.noteAccess.resolve(note, root: root)
                guard linked.notes.allowsCLIWrite(at: url) else { throw WorkStoreError.busy }
                let snapshot: NoteFileSnapshot
                if command.operation == .appendNote {
                    let proposal = try await linked.noteAccess.previewAppend(note: note, root: root, markdown: command.markdown!)
                    guard proposal.expectedHash == command.expectedHash else { throw WorkStoreError.fileChanged }
                    snapshot = try await linked.noteAccess.applyAppend(proposal)
                } else {
                    snapshot = try await linked.noteAccess.replace(note: note, root: root, expectedHash: command.expectedHash!, markdown: command.markdown!)
                }
                reply.path = url.path; reply.sha256 = snapshot.sha256; reply.partialWrite = true
                linked.notes.receivedCLIWrite(at: url, markdown: snapshot.markdown)
                reply.note = try await linked.registerNote(url, replaced: true)
                reply.partialWrite = false
                linked.notes.scan()
            }
            await app.refresh(); await linked.refresh()
            reply.revision = try await repository.info().revision
        } catch { reply.error = (error as? WorkStoreError) ?? .unavailable }
        return reply
    }
}
