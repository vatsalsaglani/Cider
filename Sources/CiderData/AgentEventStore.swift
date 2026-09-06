import Foundation
import CiderDomain

/// A bounded observer batch that has been reduced but not yet acknowledged.
///
/// The ledger and spool have deliberately separate commits: linked-work journal
/// storage must receive the source events before either can be advanced.
public struct AgentEventBatch: Sendable {
    public let root: URL
    public let ledger: AgentLedger
    public let events: [AgentEvent]
    /// Events not already present in the persisted ledger before this read.
    /// UI peeks use this rather than a replayed ledger history.
    public let freshEvents: [AgentEvent]
    let files: [URL]

    init(root: URL, ledger: AgentLedger, events: [AgentEvent], freshEvents: [AgentEvent], files: [URL]) {
        self.root = root
        self.ledger = ledger
        self.events = events
        self.freshEvents = freshEvents
        self.files = files
    }
}

// Blocking filesystem work runs on the caller's dedicated utility queue.
public enum AgentEventStore {
    /// Reads at most one spool batch and applies it in memory only.
    public static func readBatch(root: URL) throws -> AgentEventBatch {
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
        let ordered = events.sorted { lhs, rhs in
            lhs.1.time == rhs.1.time ? lhs.1.id.uuidString < rhs.1.id.uuidString : lhs.1.time < rhs.1.time
        }
        var seen = Set(ledger.seen)
        var freshEvents: [AgentEvent] = []
        for (_, event) in ordered {
            if seen.insert(event.id).inserted { freshEvents.append(event) }
            ledger.apply(event)
        }
        ledger.sessions = ledger.sessions.filter { Date.now.timeIntervalSince($0.value.updated) < 86400 }
        return AgentEventBatch(root: root, ledger: ledger, events: ordered.map(\.1), freshEvents: freshEvents, files: ordered.map(\.0))
    }

    /// Persists the reduced ledger and then removes exactly the batch files.
    /// A failure leaves remaining spool records for replay; journal dedupe makes
    /// a crash between its commit and this acknowledgement safe.
    public static func acknowledge(_ batch: AgentEventBatch) throws {
        let fm = FileManager.default
        let state = batch.root.appending(path: "sessions.json")
        try JSONEncoder().encode(batch.ledger).write(to: state, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
        for file in batch.files { try fm.removeItem(at: file) }
    }

    /// Legacy/isolated-test convenience. Production callers must stage journal
    /// ingestion between `readBatch` and `acknowledge`.
    public static func ingest(root: URL) throws -> AgentLedger {
        let batch = try readBatch(root: root)
        try acknowledge(batch)
        return batch.ledger
    }
}
