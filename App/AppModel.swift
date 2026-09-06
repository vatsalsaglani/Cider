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
    private let store: SnapshotStore
    private var revision: UInt64 = 0

    init(storeURL: URL? = nil) {
        let root = URL.applicationSupportDirectory.appending(path: "Cinder", directoryHint: .isDirectory)
        store = SnapshotStore(url: storeURL ?? root.appending(path: "workspace.json"))
    }
    func load() async {
        do { snapshot = try await store.load(); ready = true }
        catch { self.error = "Your workspace could not be opened. The original file has been kept." }
    }
    func tasks(on day: LocalDay) -> [TaskItem] {
        snapshot.tasks.filter { $0.plannedDay == day }.sorted { !$0.completed && $1.completed }
    }
    func createTask(_ title: String, day: LocalDay) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return await commit { $0.tasks.append(TaskItem(title: title, plannedDay: day)) }
    }
    func toggle(_ task: TaskItem) async {
        _ = await commit { value in
            if let index = value.tasks.firstIndex(where: { $0.id == task.id }) { value.tasks[index].completed.toggle() }
        }
    }
    func update(_ task: TaskItem) async -> Bool {
        await commit { value in
            if let index = value.tasks.firstIndex(where: { $0.id == task.id }) { value.tasks[index] = task }
        }
    }
    func setNotch(_ preferences: NotchPreferences) async {
        _ = await commit { $0.notch = preferences }
    }
    private func commit(_ change: (inout AppSnapshot) -> Void) async -> Bool {
        guard ready, !saving else { return false }
        saving = true
        defer { saving = false }
        var next = snapshot
        change(&next)
        revision += 1
        do { try await store.save(next, revision: revision); snapshot = next; return true }
        catch { self.error = "This change could not be saved. Your draft is still here. Try again."; return false }
    }
}
