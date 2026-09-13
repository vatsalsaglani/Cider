import Foundation
import Darwin

public enum PluginProcessError: Error, Sendable { case failed(Int32), timedOut }

/// Installer commands use argv, check exit status and never launch a shell.
public enum PluginProcess {
    public static func run(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil) async throws -> Data {
        let worker = Task.detached(priority: .utility) { try execute(executable, arguments, environment: environment) }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }
    private static func execute(_ executable: URL, _ arguments: [String], environment: [String: String]?) throws -> Data {
        try Task.checkCancellation()
        let output = URL.temporaryDirectory.appending(path: "cider-plugin-" + UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output); defer { try? handle.close() }
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        var resolvedEnvironment = environment ?? ProcessInfo.processInfo.environment
        resolvedEnvironment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (resolvedEnvironment["PATH"] ?? "/usr/bin:/bin")
        process.environment = resolvedEnvironment
        process.currentDirectoryURL = URL.temporaryDirectory
        process.standardOutput = handle; process.standardError = FileHandle.nullDevice; process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = Date.now.addingTimeInterval(30)
        while process.isRunning {
            let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if Task.isCancelled || Date.now > deadline || size > 2_000_000 {
                process.terminate(); Thread.sleep(forTimeInterval: 0.1)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit(); throw PluginProcessError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.025)
        }
        guard process.terminationStatus == 0 else { throw PluginProcessError.failed(process.terminationStatus) }
        let reader = try FileHandle(forReadingFrom: output); defer { try? reader.close() }
        let data = try reader.read(upToCount: 2_000_001) ?? Data()
        guard data.count <= 2_000_000 else { throw PluginProcessError.timedOut }
        return data
    }
}
