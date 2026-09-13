import Foundation
import CiderDomain

enum CursorHookSetup {
    static func propose(destination: URL, helper: URL, removing: Bool, before: Data?, document original: [String: Any], command: String) throws -> HookProposal {
        var document = original
        if let version = document["version"] {
            guard let number = version as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number == 1 else { throw CocoaError(.coderInvalidValue) }
        }
        var hooks = document["hooks"] as? [String: Any] ?? [:]
        for event in TrackedProvider.cursor.events {
            if let value = hooks[event], !(value is [[String: Any]]) { throw CocoaError(.coderInvalidValue) }
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll { ($0["command"] as? String) == command && ($0["type"] == nil || ($0["type"] as? String) == "command") }
            if !removing { entries.append(["command": command, "timeout": 1]) }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        document["hooks"] = hooks
        if !removing { document["version"] = 1 }
        let fragment: [String: Any] = ["version": 1, "hooks": Dictionary(uniqueKeysWithValues: TrackedProvider.cursor.events.map { ($0, [["command": command, "timeout": 1]]) })]
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        let preview = (removing ? "Remove these Cider entries only:\n" : "Merge these Cider entries:\n") + String(decoding: try JSONSerialization.data(withJSONObject: fragment, options: options), as: UTF8.self)
        return HookProposal(provider: .cursor, destination: destination, helper: helper, removing: removing, preview: preview, before: before, after: try JSONSerialization.data(withJSONObject: document, options: options))
    }
}
