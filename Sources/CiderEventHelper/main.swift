import Foundation
import Darwin
import CiderDomain

// An observer must never delay or change the agent's decision.
signal(SIGALRM) { _ in _exit(0) }
alarm(1)
if CommandLine.arguments.count >= 2, let provider = TrackedProvider(rawValue: CommandLine.arguments[1]) {
    do {
        var input = Data()
        while let chunk = try FileHandle.standardInput.read(upToCount: 16384), !chunk.isEmpty {
            input.append(chunk)
            if input.count > 1_048_576 { exit(0) }
        }
        var event = try AgentEvent(provider: provider, payload: input)
        event.origin = captureOrigin()
        let base = CommandLine.arguments.count == 3 ? URL(fileURLWithPath: CommandLine.arguments[2]) : FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Cider/Tracking/spool")
        guard base.resolvingSymlinksInPath().path == base.standardizedFileURL.path else { exit(0) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard try FileManager.default.contentsOfDirectory(atPath: base.path).count < 2048 else { exit(0) }
        let data = try JSONEncoder().encode(event)
        guard data.count <= 8192 else { exit(0) }
        let file = base.appending(path: event.id.uuidString + ".json")
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    } catch { }
}
