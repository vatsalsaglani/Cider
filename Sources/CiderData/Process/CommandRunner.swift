import Foundation
import Darwin

public enum CommandFailure: Error, Sendable { case timedOut }

public enum CommandRunner {
    /// Uses argv, a private output file and a deadline; never invokes a shell.
    public static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 25, environment: [String: String]? = nil) async throws -> Data {
        let worker = Task.detached(priority: .utility) { try execute(executable, arguments: arguments, timeout: timeout, environment: environment) }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }
    private static func execute(_ executable: String, arguments: [String], timeout: TimeInterval, environment supplied: [String: String]?) throws -> Data {
        try Task.checkCancellation()
        let output = URL.temporaryDirectory.appending(path: UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output); defer { try? handle.close() }
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        var environment = supplied ?? ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin") + ":" + FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin").path
        process.environment = environment
        process.standardOutput = handle; process.standardError = FileHandle.nullDevice; process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Task.isCancelled {
                process.terminate(); Thread.sleep(forTimeInterval: 0.1)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit(); throw CancellationError()
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0
            if Date() >= deadline || size > 2_000_000 { process.terminate(); Thread.sleep(forTimeInterval: 0.1); if process.isRunning { kill(process.processIdentifier, SIGKILL) }; process.waitUntilExit(); throw CommandFailure.timedOut }
            Thread.sleep(forTimeInterval: 0.05)
        }
        let data = try Data(contentsOf: output)
        guard !data.isEmpty else { throw CocoaError(.fileReadUnknown) }
        return data
    }
}
