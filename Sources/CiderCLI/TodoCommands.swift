import Foundation
import CiderDomain
import CiderData

enum TodoCommands {
    static func execute(_ arguments: CLIArguments) async throws -> CLIResult {
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
            let page = try await repository.tasks(TaskQuery(day: LocalDay(), limit: 20))
            return CLIResult(page.items, revision: page.revision, nextCursor: page.nextCursor, truncated: page.nextCursor != nil)
        }
    }
}
