import Foundation
import CiderDomain

enum CLICommand: Equatable {
    case list(today: Bool)
    case show(UUID)
    case activity(UUID, since: Int64?)
    case context(UUID, includeNotes: Bool)
    case summarizeToday
}

struct CLIArguments: Equatable {
    var storeURL: URL
    var command: CLICommand
    var json: Bool

    static func parse(_ arguments: [String]) throws -> CLIArguments {
        var values = Array(arguments.dropFirst())
        var storeURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Cider/work.sqlite")
        var json = false
        func takeFlag(_ flag: String) -> Bool {
            guard let index = values.firstIndex(of: flag) else { return false }
            values.remove(at: index); return true
        }
        if let index = values.firstIndex(of: "--store") {
            guard values.indices.contains(index + 1) else { throw WorkStoreError.invalidInput }
            let path = values[index + 1]
            guard !path.isEmpty else { throw WorkStoreError.invalidInput }
            storeURL = URL(fileURLWithPath: path).standardizedFileURL
            values.removeSubrange(index...(index + 1))
        }
        json = takeFlag("--json")
        guard values.first == "todo" else { throw WorkStoreError.invalidInput }
        values.removeFirst()
        guard let verb = values.first else { throw WorkStoreError.invalidInput }
        values.removeFirst()
        switch verb {
        case "list":
            let today = takeFlag("--today")
            guard values.isEmpty else { throw WorkStoreError.invalidInput }
            return CLIArguments(storeURL: storeURL, command: .list(today: today), json: json)
        case "show":
            guard values.count == 1, let id = UUID(uuidString: values[0]) else { throw WorkStoreError.invalidInput }
            return CLIArguments(storeURL: storeURL, command: .show(id), json: json)
        case "activity":
            guard let first = values.first, let id = UUID(uuidString: first) else { throw WorkStoreError.invalidInput }
            values.removeFirst()
            var since: Int64?
            if let index = values.firstIndex(of: "--since") {
                guard values.indices.contains(index + 1), let cursor = Int64(values[index + 1]), cursor >= 0 else { throw WorkStoreError.invalidInput }
                since = cursor; values.removeSubrange(index...(index + 1))
            }
            guard values.isEmpty else { throw WorkStoreError.invalidInput }
            return CLIArguments(storeURL: storeURL, command: .activity(id, since: since), json: json)
        case "context":
            guard let first = values.first, let id = UUID(uuidString: first) else { throw WorkStoreError.invalidInput }
            values.removeFirst()
            let includeNotes = takeFlag("--include-notes")
            guard values.isEmpty else { throw WorkStoreError.invalidInput }
            return CLIArguments(storeURL: storeURL, command: .context(id, includeNotes: includeNotes), json: json)
        case "summarize-context":
            guard takeFlag("--today"), values.isEmpty else { throw WorkStoreError.invalidInput }
            return CLIArguments(storeURL: storeURL, command: .summarizeToday, json: json)
        default: throw WorkStoreError.invalidInput
        }
    }
}
