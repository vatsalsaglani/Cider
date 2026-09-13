import Foundation
import Observation

struct WorkspaceLocation: Equatable {
    var section: String = "Today"
    var task: UUID?
    var note: URL?
}

/// Scene-local browser history. Replacing a destination after Back drops the forward branch.
@MainActor @Observable
final class WorkspaceHistory {
    private(set) var entries: [WorkspaceLocation] = [WorkspaceLocation()]
    private(set) var index = 0
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < entries.count }
    var parentTask: (id: UUID, offset: Int)? {
        guard entries[index].section == "Notes", index > 0 else { return nil }
        for previous in stride(from: index - 1, through: 0, by: -1) {
            if let id = entries[previous].task { return (id, previous - index) }
            if entries[previous].section != "Notes" { break }
        }
        return nil
    }
    func record(_ location: WorkspaceLocation) {
        guard entries[index] != location else { return }
        entries = Array(entries.prefix(index + 1))
        entries.append(location)
        if entries.count > 100 { entries.removeFirst() }
        index = entries.count - 1
    }
    func destination(_ offset: Int) -> WorkspaceLocation? {
        let next = index + offset
        return entries.indices.contains(next) ? entries[next] : nil
    }
    func move(_ offset: Int) {
        guard destination(offset) != nil else { return }
        index += offset
    }
}
