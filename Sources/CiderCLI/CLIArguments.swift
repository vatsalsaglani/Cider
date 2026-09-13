import Foundation
import CiderDomain

enum CLICommand: Equatable {
    case help
    case list(today: Bool)
    case show(UUID)
    case activity(UUID, since: Int64?)
    case context(UUID, includeNotes: Bool)
    case summarizeToday
    case folders
    case notes(root: UUID?, cursor: String?)
    case note(UUID)
    case write(CLIWriteCommand)
}

struct CLIArguments: Equatable {
    var storeURL: URL
    var command: CLICommand
    var json: Bool

    static func parse(_ arguments: [String]) throws -> CLIArguments {
        var options = try CLIOptions(Array(arguments.dropFirst()))
        let storePath = try options.take("--store")
        guard storePath != "" else { throw WorkStoreError.invalidInput }
        let store = storePath.map { URL(fileURLWithPath: $0).standardizedFileURL }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Cider/work.sqlite")
        let json = options.flag("--json")
        if options.flag("--help") || options.words == ["help"] {
            return CLIArguments(storeURL: store, command: .help, json: json)
        }
        guard options.words.count >= 2 else { throw WorkStoreError.invalidInput }
        let group = options.words.removeFirst(), verb = options.words.removeFirst()
        let command: CLICommand
        switch (group, verb) {
        case ("todo", "list"): command = .list(today: options.flag("--today"))
        case ("todo", "show"): command = .show(try options.id())
        case ("todo", "activity"):
            let id = try options.id()
            let since = try options.integer("--since", minimum: 0)
            command = .activity(id, since: since)
        case ("todo", "context"): command = .context(try options.id(), includeNotes: options.flag("--include-notes"))
        case ("todo", "summarize-context"):
            guard options.flag("--today") else { throw WorkStoreError.invalidInput }
            command = .summarizeToday
        case ("folder", "list"): command = .folders
        case ("note", "list"): command = .notes(root: try options.uuid("--folder"), cursor: try options.take("--cursor"))
        case ("note", "show"): command = .note(try options.id())
        default: command = .write(try CLIWriteArguments.parse(group: group, verb: verb, options: &options))
        }
        guard options.words.isEmpty, options.values.isEmpty else { throw WorkStoreError.invalidInput }
        return CLIArguments(storeURL: store, command: command, json: json)
    }
}

struct CLIOptions {
    var words: [String] = []
    var values: [String: String] = [:]
    init(_ arguments: [String]) throws {
        let flags: Set<String> = ["--json", "--today", "--include-notes", "--help"]
        let valued: Set<String> = ["--store", "--since", "--title", "--description-file", "--day", "--status",
                                  "--if-revision", "--markdown-file", "--if-hash", "--folder", "--note", "--role", "--cursor"]
        var index = 0
        while index < arguments.count {
            let item = arguments[index]; index += 1
            if flags.contains(item) {
                guard values.updateValue("true", forKey: item) == nil else { throw WorkStoreError.invalidInput }
            } else if valued.contains(item) {
                guard index < arguments.count, values[item] == nil else { throw WorkStoreError.invalidInput }
                values[item] = arguments[index]; index += 1
            } else {
                guard !item.hasPrefix("--") else { throw WorkStoreError.invalidInput }
                words.append(item)
            }
        }
    }
    mutating func take(_ key: String) throws -> String? { values.removeValue(forKey: key) }
    mutating func flag(_ key: String) -> Bool { values.removeValue(forKey: key) != nil }
    mutating func id() throws -> UUID {
        guard !words.isEmpty, let id = UUID(uuidString: words.removeFirst()) else { throw WorkStoreError.invalidInput }; return id
    }
    mutating func uuid(_ key: String) throws -> UUID? {
        guard let text = try take(key) else { return nil }
        guard let id = UUID(uuidString: text) else { throw WorkStoreError.invalidInput }; return id
    }
    mutating func integer(_ key: String, minimum: Int64) throws -> Int64? {
        guard let text = try take(key) else { return nil }
        guard let value = Int64(text), value >= minimum else { throw WorkStoreError.invalidInput }; return value
    }
}
