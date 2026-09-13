import Foundation
import CiderDomain

public struct HookProposal: Identifiable, Sendable {
    public let id = UUID()
    public let provider: TrackedProvider
    public let destination: URL
    public let helper: URL
    public let removing: Bool
    public let preview: String
    let before: Data?
    let after: Data
}
public enum AgentHookSetup {
    public static func destination(provider: TrackedProvider, home: URL, environment: [String: String]) -> URL {
        switch provider {
        case .codex: return (environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appending(path: ".codex")).appending(path: "hooks.json")
        case .claude: return (environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) } ?? home.appending(path: ".claude")).appending(path: "settings.json")
        case .cursor: return home.appending(path: ".cursor/hooks.json")
        }
    }
    public static func command(helper: URL, provider: TrackedProvider) -> String {
        "'" + helper.path.replacingOccurrences(of: "'", with: "'\\''") + "' " + provider.rawValue
    }
    public static func propose(provider: TrackedProvider, destination: URL, helper: URL, removing: Bool) throws -> HookProposal {
        guard destination.resolvingSymlinksInPath().path == destination.standardizedFileURL.path else { throw CocoaError(.fileWriteNoPermission) }
        let before = FileManager.default.fileExists(atPath: destination.path) ? try Data(contentsOf: destination) : nil
        guard (before?.count ?? 0) < 1_048_576 else { throw CocoaError(.fileReadTooLarge) }
        var document: [String: Any] = [:]
        if let before {
            guard let decoded = try JSONSerialization.jsonObject(with: before) as? [String: Any] else { throw CocoaError(.coderInvalidValue) }
            document = decoded
        }
        if let hooks = document["hooks"], !(hooks is [String: Any]) { throw CocoaError(.coderInvalidValue) }
        var hooks = document["hooks"] as? [String: Any] ?? [:]
        let cmd = command(helper: helper, provider: provider)
        if provider == .cursor {
            return try CursorHookSetup.propose(destination: destination, helper: helper, removing: removing, before: before, document: document, command: cmd)
        }
        for event in provider.events {
            if let value = hooks[event], !(value is [[String: Any]]) { throw CocoaError(.coderInvalidValue) }
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries = entries.compactMap { entry in
                guard let children = entry["hooks"] as? [[String: Any]] else { return entry }
                let kept = children.filter { !(($0["command"] as? String) == cmd && ($0["type"] as? String) == "command") }
                if kept.count == children.count { return entry }
                if kept.isEmpty { return nil }
                var copy = entry; copy["hooks"] = kept; return copy
            }
            if !removing { entries.append(["hooks": [["type": "command", "command": cmd, "timeout": 1]]]) }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        document["hooks"] = hooks
        let after = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        let fragment: [String: Any] = ["hooks": Dictionary(uniqueKeysWithValues: provider.events.map { ($0, [["hooks": [["type": "command", "command": cmd, "timeout": 1]]]]) })]
        let fragmentData = try JSONSerialization.data(withJSONObject: fragment, options: [.prettyPrinted, .sortedKeys])
        let preview = (removing ? "Remove these Cider entries only:\n" : "Merge these Cider entries:\n") + String(decoding: fragmentData, as: UTF8.self)
        return HookProposal(provider: provider, destination: destination, helper: helper, removing: removing, preview: preview, before: before, after: after)
    }
    public static func apply(_ proposal: HookProposal, bundledHelper: URL) throws {
        let fm = FileManager.default
        let current = fm.fileExists(atPath: proposal.destination.path) ? try Data(contentsOf: proposal.destination) : nil
        guard current == proposal.before, proposal.destination.resolvingSymlinksInPath().path == proposal.destination.standardizedFileURL.path else { throw CocoaError(.fileWriteFileExists) }
        if !proposal.removing {
            guard proposal.helper.resolvingSymlinksInPath().path == proposal.helper.standardizedFileURL.path else { throw CocoaError(.fileWriteNoPermission) }
            try fm.createDirectory(at: proposal.helper.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try Data(contentsOf: bundledHelper).write(to: proposal.helper, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: proposal.helper.path)
        }
        try fm.createDirectory(at: proposal.destination.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try proposal.after.write(to: proposal.destination, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: proposal.destination.path)
    }
}
