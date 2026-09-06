import Foundation
import CiderDomain

/// Serial atomic writes run on a dedicated I/O queue, not a cooperative executor.
public actor SnapshotStore {
    private let url: URL
    private let io = DispatchQueue(label: "app.cider.snapshot-io", qos: .utility)
    private var latestRevision: UInt64 = 0
    public init(url: URL) { self.url = url }

    public func load() async throws -> AppSnapshot {
        let url = url
        return try await withCheckedThrowingContinuation { continuation in
            io.async {
                do {
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        continuation.resume(returning: AppSnapshot()); return
                    }
                    let value = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: url))
                    guard value.version == 1 else { throw CocoaError(.fileReadUnknown) }
                    continuation.resume(returning: value)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    public func save(_ snapshot: AppSnapshot, revision: UInt64) async throws {
        guard revision > latestRevision else { return }
        latestRevision = revision
        let url = url
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            io.async {
                do {
                    let bytes = try JSONEncoder().encode(snapshot)
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try bytes.write(to: url, options: .atomic)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
