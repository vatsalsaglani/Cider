import Foundation
import Observation
import CiderDomain

/// Scene-owned adapter. Views retain their drafts separately from these saved snapshots.
@MainActor @Observable
public final class LinkedWorkModel {
    public private(set) var taskPage: WorkPage<WorkTask>?
    public private(set) var selectedDetail: TaskDetail?
    public private(set) var availableChats: [ChatReference] = []
    public private(set) var error: String?
    private var operations = 0
    public var busy: Bool { operations > 0 }
    public let repository: any WorkRepository
    public let noteAccess: any LinkedNoteAccess
    @ObservationIgnored private var listGeneration = 0
    @ObservationIgnored private var detailGeneration = 0
    @ObservationIgnored private var errorGeneration = 0

    public init(repository: any WorkRepository, noteAccess: any LinkedNoteAccess) {
        self.repository = repository; self.noteAccess = noteAccess
    }
    public func refresh(_ query: TaskQuery) async {
        listGeneration += 1; let generation = listGeneration
        let operation = begin(); defer { operations -= 1 }
        do {
            try WorkLimits.validate(limit: query.limit)
            let page = try await repository.tasks(query)
            guard generation == listGeneration, !Task.isCancelled else { return }
            taskPage = page; clearError(operation)
        } catch { if generation == listGeneration { report(error, operation: operation) } }
    }
    public func loadDetail(_ id: UUID) async {
        detailGeneration += 1; let generation = detailGeneration
        let operation = begin(); defer { operations -= 1 }
        if selectedDetail?.task.id != id { selectedDetail = nil }
        do {
            let detail = try await repository.detail(id)
            guard generation == detailGeneration, !Task.isCancelled else { return }
            selectedDetail = detail; clearError(operation)
        } catch { if generation == detailGeneration { report(error, operation: operation) } }
    }
    /// Mutations do not erase or rebase a view's draft. Callers reload after a successful receipt.
    @discardableResult public func perform(_ mutation: WorkMutation) async -> Bool {
        let operation = begin(); defer { operations -= 1 }
        do {
            _ = try await repository.apply(mutation)
            // Invalidate reads started before this write so they cannot publish stale snapshots.
            listGeneration += 1; detailGeneration += 1
            clearError(operation); return true
        } catch { report(error, operation: operation); return false }
    }
    public func updateAvailableChats(_ chats: [ChatReference]) {
        var seen = Set<ChatIdentity>()
        availableChats = chats.prefix(WorkLimits.list).filter { seen.insert($0.identity).inserted }
    }
    private func begin() -> Int { operations += 1; errorGeneration += 1; return errorGeneration }
    private func clearError(_ operation: Int) { if operation == errorGeneration { error = nil } }
    private func report(_ failure: Error, operation: Int) {
        guard operation == errorGeneration, !(failure is CancellationError), !Task.isCancelled else { return }
        error = (failure as? WorkStoreError) == .conflict
            ? "This item changed. Your draft is still here; reload and compare before saving."
            : "This request could not be completed. Your changes are still here. Try again."
    }
}
