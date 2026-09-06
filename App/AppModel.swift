import Foundation
import Observation
import CiderDomain
import CiderData

@MainActor @Observable
final class AppModel {
    private(set) var snapshot = AppSnapshot()
    private(set) var ready = false
    private(set) var saving = false
    @ObservationIgnored var openWorkspace: (() -> Void)?
    var error: String?
    var dayDraft = ""
    var quickDraft = ""
    var notchDate = Date.now
    var notchDraft = ""
    private(set) var repository: (any WorkRepository)?
    private(set) var workTasks: [WorkTask] = []
    private let storeURL: URL
    private let legacyURL: URL
    private let folderPaths: [String]
    private var readGeneration = 0

    init(storeURL: URL? = nil, legacyURL: URL? = nil, folderPaths: [String]? = nil) {
        let resolvedURL = storeURL ?? URL.applicationSupportDirectory.appending(path: "Cider/work.sqlite")
        self.storeURL = resolvedURL
        self.folderPaths = folderPaths ?? UserDefaults.standard.stringArray(forKey: "workspaceFolders") ?? []
        self.legacyURL = legacyURL ?? URL.applicationSupportDirectory.appending(path: "Cinder/workspace.json")
    }
    func load() async {
        guard !ready else { return }
        do {
            repository = try await SQLiteWorkRepository.open(at: storeURL, access: .appReadWrite,
                legacy: LegacyImport(workspaceURL: legacyURL,
                    folderPaths: folderPaths))
            try await reload()
            ready = true
        } catch { self.error = "Your workspace could not be opened. The original file has been kept. Retry opening Cider." }
    }
    func refresh() async {
        guard repository != nil else { return }
        do { try await reload() }
        catch { self.error = "Your saved tasks could not be refreshed. The last view has been kept." }
    }
    private func reload() async throws {
        guard let repository else { throw WorkStoreError.unavailable }
        readGeneration += 1
        let generation = readGeneration
        var rows: [WorkTask] = []
        var cursor: String?
        repeat {
            let page = try await repository.tasks(TaskQuery(cursor: cursor, limit: WorkLimits.list))
            rows.append(contentsOf: page.items); cursor = page.nextCursor
        } while cursor != nil
        let preferences = try await repository.notchPreferences()
        guard generation == readGeneration else { return }
        workTasks = rows
        snapshot.tasks = rows.map(\.legacyItem)
        snapshot.notch = preferences
    }
    func tasks(on day: LocalDay) -> [TaskItem] {
        snapshot.tasks.filter { $0.plannedDay == day }.sorted { !$0.completed && $1.completed }
    }
    func createTask(_ title: String, day: LocalDay) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return await commit(.saveTask(task: WorkTask(title: title, plannedDay: day,
            sortOrder: (workTasks.map(\.sortOrder).max() ?? -1) + 1)))
    }
    func toggle(_ task: TaskItem) async {
        guard var row = workTasks.first(where: { $0.id == task.id }) else { return }
        row.toggleCompletion()
        _ = await commit(.saveTask(task: row))
    }
    func update(_ task: TaskItem) async -> Bool {
        guard var row = workTasks.first(where: { $0.id == task.id }) else { return false }
        row.title = task.title; row.plannedDay = task.plannedDay
        return await commit(.saveTask(task: row))
    }
    func setNotch(_ preferences: NotchPreferences) async {
        _ = await commit(.setNotch(preferences: preferences))
    }
    private func commit(_ change: WorkChange) async -> Bool {
        guard ready, !saving, let repository else { return false }
        saving = true
        defer { saving = false }
        do {
            _ = try await repository.apply(WorkMutation(change: change))
            await refresh()
            return true
        } catch { self.error = "This change could not be saved. Your draft is still here. Try again."; return false }
    }
}
