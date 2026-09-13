import Foundation
import CryptoKit
import Darwin
import CiderDomain

/// A private, per-store inbox. The GUI remains the only CLI mutation executor.
public enum CLIWriteTransport {
    public struct Lease: Codable, Sendable { public let id: UUID; public let processID: Int32 }
    public static func directory(store: URL) -> URL {
        let canonical = store.standardizedFileURL.resolvingSymlinksInPath()
        let key = SHA256.hash(data: Data(canonical.path.utf8))
            .prefix(12).map { String(format: "%02x", $0) }.joined()
        return canonical.deletingLastPathComponent().appending(path: ".cider-cli-" + key)
    }
    public static func start(at root: URL) throws -> (Lease, Int32) {
        guard mkdir(root.path, 0o700) == 0 || errno == EEXIST else { throw WorkStoreError.unavailable }
        try validateDirectory(root)
        let descriptor = Darwin.open(root.appending(path: "lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw WorkStoreError.unavailable }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { close(descriptor); throw WorkStoreError.busy }
        do {
            for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                where ["request", "response"].contains(file.pathExtension) && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil {
                try FileManager.default.removeItem(at: file)
            }
            let lease = Lease(id: UUID(), processID: getpid())
            try write(lease, to: root.appending(path: "lease"))
            return (lease, descriptor)
        } catch { close(descriptor); throw error }
    }
    public static func stop(at root: URL, descriptor: Int32) {
        try? FileManager.default.removeItem(at: root.appending(path: "lease"))
        flock(descriptor, LOCK_UN); close(descriptor)
    }
    public static func takeRequests(at root: URL, lease: Lease) throws -> [CLIWriteRequest] {
        try validateDirectory(root)
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "request" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }.prefix(32)
        var requests: [CLIWriteRequest] = []
        for file in files {
            defer { try? FileManager.default.removeItem(at: file) }
            guard let request = try? read(CLIWriteRequest.self, from: file), request.schemaVersion == 1,
                  request.id.uuidString.lowercased() == file.deletingPathExtension().lastPathComponent,
                  request.leaseID == lease.id, (0..<30).contains(Date.now.timeIntervalSince(request.createdAt)) else { continue }
            requests.append(request)
        }
        return requests
    }
    public static func respond(_ reply: CLIWriteReply, id: UUID, at root: URL) throws {
        try write(reply, to: root.appending(path: id.uuidString.lowercased() + ".response"))
    }
    public static func send(_ command: CLIWriteCommand, store: URL) async throws -> CLIWriteReply {
        try command.validate()
        let root = directory(store: store)
        let lease = try await AgentIO.run {
            try validateDirectory(root)
            let lease = try read(Lease.self, from: root.appending(path: "lease"))
            guard kill(lease.processID, 0) == 0 else { throw WorkStoreError.unavailable }
            return lease
        }
        let request = CLIWriteRequest(leaseID: lease.id, command: command)
        let input = root.appending(path: request.id.uuidString.lowercased() + ".request")
        let output = root.appending(path: request.id.uuidString.lowercased() + ".response")
        try await AgentIO.run { try write(request, to: input) }
        for _ in 0..<375 {
            if let reply = try await AgentIO.run({ () throws -> CLIWriteReply? in
                guard FileManager.default.fileExists(atPath: output.path) else { return nil }
                defer { try? FileManager.default.removeItem(at: output) }
                return try read(CLIWriteReply.self, from: output)
            }) { return reply }
            try await Task.sleep(for: .milliseconds(80))
        }
        // A timeout does not prove the command failed; the app may have committed it.
        throw WorkStoreError.busy
    }
    private static func validateDirectory(_ root: URL) throws {
        var info = stat()
        guard lstat(root.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else { throw WorkStoreError.unavailable }
    }
    private static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw WorkStoreError.unavailable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(),
              info.st_size <= WorkLimits.contextBytes else { throw WorkStoreError.invalidInput }
        let data = try handle.read(upToCount: WorkLimits.contextBytes + 1) ?? Data()
        guard data.count <= WorkLimits.contextBytes else { throw WorkStoreError.outputLimit }
        return try JSONDecoder().decode(type, from: data)
    }
    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        guard data.count <= WorkLimits.contextBytes else { throw WorkStoreError.outputLimit }
        // Prepare permissions before publication: the app may consume and remove
        // a request immediately after its final name appears in the inbox.
        let temporary = url.deletingLastPathComponent().appending(path: ".pending-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        guard rename(temporary.path, url.path) == 0 else { throw WorkStoreError.unavailable }
    }
}
