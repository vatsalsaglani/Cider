import Foundation
import CiderDomain

// Blocking filesystem work runs on the caller's dedicated utility queue.
public enum AgentEventStore {
    public static func ingest(root: URL) throws -> AgentLedger {
        let fm = FileManager.default
        let spool = root.appending(path: "spool")
        try fm.createDirectory(at: spool, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let state = root.appending(path: "sessions.json")
        var ledger: AgentLedger
        if fm.fileExists(atPath: state.path) { ledger = try JSONDecoder().decode(AgentLedger.self, from: Data(contentsOf: state)) }
        else { ledger = AgentLedger() }
        let files = try fm.contentsOfDirectory(at: spool, includingPropertiesForKeys: [.isSymbolicLinkKey, .fileSizeKey]).filter { $0.pathExtension == "json" }.prefix(2048)
        var events: [(URL, AgentEvent)] = []
        for file in files {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 8193) <= 8192 else { continue }
            if let value = try? JSONDecoder().decode(AgentEvent.self, from: Data(contentsOf: file)), value.schemaVersion == 1 { events.append((file, value)) }
        }
        for (_, event) in events.sorted(by: { $0.1.time < $1.1.time }) { ledger.apply(event) }
        ledger.sessions = ledger.sessions.filter { Date.now.timeIntervalSince($0.value.updated) < 86400 }
        try JSONEncoder().encode(ledger).write(to: state, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
        for (file, _) in events { try? fm.removeItem(at: file) }
        return ledger
    }
}
