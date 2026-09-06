import Foundation

@MainActor
final class SystemMediaBridge {
    private var process: Process?
    private var buffer = Data()
    private var generation = UUID()
    var failed: (() -> Void)?
    var receive: ((Data) -> Void)?
    private let directory = Bundle.main.bundleURL.appending(path: "Contents/Helpers")
    var available: Bool { FileManager.default.fileExists(atPath: directory.appending(path: "MediaRemoteAdapter.framework/MediaRemoteAdapter").path) }
    func start() {
        stop()
        let generation = generation
        let pipe = Pipe(), process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = arguments + ["stream", "--no-diff", "--debounce=150"]
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.buffer.append(data)
                guard self.buffer.count < 16_000_000 else { self.buffer.removeAll(); return }
                while let end = self.buffer.firstIndex(of: 10) {
                    let line = self.buffer.prefix(upTo: end)
                    self.buffer.removeSubrange(...end)
                    self.receive?(Data(line))
                }
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.failed?()
            }
        }
        do { try process.run(); self.process = process } catch { pipe.fileHandleForReading.readabilityHandler = nil; failed?() }
    }
    func send(_ command: Int) {
        guard [2, 4, 5].contains(command) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = arguments + ["send", String(command)]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            Task { try? await Task.sleep(for: .seconds(5)); if process.isRunning { process.terminate() } }
        } catch { failed?() }
    }
    private var arguments: [String] {
        [directory.appending(path: "mediaremote-adapter.pl").path, directory.appending(path: "MediaRemoteAdapter.framework").path]
    }
    func stop() {
        generation = UUID(); buffer.removeAll()
        if let pipe = process?.standardOutput as? Pipe { pipe.fileHandleForReading.readabilityHandler = nil }
        if process?.isRunning == true { process?.terminate() }
        process = nil
    }
}
