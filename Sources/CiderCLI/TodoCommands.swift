import Foundation
import CiderDomain
import CiderData

enum TodoCommands {
    static func execute(_ arguments: CLIArguments) async throws -> CLIResult {
        if case .write(let command) = arguments.command {
            let reply = try await CLIWriteTransport.send(command, store: arguments.storeURL)
            if reply.error != nil { throw CLIWriteFailure(reply: reply) }
            return CLIResult(reply, revision: reply.revision)
        }
        let repository = try await SQLiteWorkRepository.open(at: arguments.storeURL, access: .cliReadOnly)
        switch arguments.command {
        case .list(let today):
            let day = today ? LocalDay() : nil
            let page = try await repository.tasks(TaskQuery(day: day, limit: WorkLimits.list))
            return CLIResult(page.items, revision: page.revision, nextCursor: page.nextCursor, truncated: page.nextCursor != nil)
        case .show(let id):
            let detail = try await repository.detail(id)
            return CLIResult(detail, revision: detail.revision, truncated: detail.truncated)
        case .activity(let id, let since):
            let page = try await repository.journal(JournalQuery(taskID: id, afterSequence: since, limit: WorkLimits.list))
            return CLIResult(page.items, revision: page.revision, nextCursor: page.nextCursor, truncated: page.nextCursor != nil)
        case .context(let id, let includeNotes):
            let reader = TodoContextReader(repository: repository, noteAccess: LinkedNoteService())
            let bundle = try await reader.context(taskID: id, options: TodoContextOptions(includeNotes: includeNotes))
            return CLIResult(bundle, revision: bundle.storeRevision, truncated: bundle.truncated)
        case .summarizeToday:
            let reader = TodoContextReader(repository: repository, noteAccess: LinkedNoteService())
            let bundle = try await reader.todayContext()
            return CLIResult(bundle, revision: bundle.storeRevision, truncated: bundle.truncated)
        case .folders:
            return CLIResult(try await repository.folders(), revision: try await repository.info().revision)
        case .notes(let root, let cursor):
            let page = try await repository.notes(NoteQuery(rootID: root, cursor: cursor, limit: WorkLimits.list))
            return CLIResult(page.items, revision: page.revision, nextCursor: page.nextCursor, truncated: page.nextCursor != nil)
        case .note(let id):
            let note = try await repository.note(id)
            guard let root = try await repository.folders().first(where: { $0.id == note.rootID }) else { throw WorkStoreError.notFound }
            let file = try await LinkedNoteService().read(note, root: root, maxBytes: WorkLimits.noteBytes)
            return CLIResult(file, revision: try await repository.info().revision, truncated: file.truncated)
        case .help, .write: throw WorkStoreError.invalidInput
        }
    }
}

struct CLIWriteFailure: Error { let reply: CLIWriteReply }
