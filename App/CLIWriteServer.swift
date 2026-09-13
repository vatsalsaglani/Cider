import Foundation
import CiderDomain
import CiderData

@MainActor final class CLIWriteServer {
    private var watcher: (any DispatchSourceFileSystemObject)?
    private var lease: CLIWriteTransport.Lease?
    private var lock: Int32?
    private var root: URL?
    private var draining = false
    private var again = false
    private var handler: ((CLIWriteCommand) async -> CLIWriteReply)?

    func start(store: URL, handler: @escaping (CLIWriteCommand) async -> CLIWriteReply) async throws {
        guard lease == nil else { return }
        let root = CLIWriteTransport.directory(store: store)
        let (lease, lock) = try await AgentIO.run { try CLIWriteTransport.start(at: root) }
        self.root = root; self.lease = lease; self.lock = lock; self.handler = handler
        let descriptor = open(root.path, O_EVTONLY | O_CLOEXEC)
        guard descriptor >= 0 else { stop(); throw WorkStoreError.unavailable }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write], queue: .main)
        source.setEventHandler { [weak self] in Task { @MainActor in await self?.drain() } }
        source.setCancelHandler { close(descriptor) }
        watcher = source; source.resume()
        await drain()
    }
    func stop() {
        watcher?.cancel(); watcher = nil
        if let root, let lock { CLIWriteTransport.stop(at: root, descriptor: lock) }
        lease = nil; lock = nil; handler = nil
    }
    private func drain() async {
        if draining { again = true; return }
        guard let root, let lease, let handler else { return }
        draining = true; defer { draining = false }
        repeat {
            again = false
            guard let requests = try? await AgentIO.run({ try CLIWriteTransport.takeRequests(at: root, lease: lease) }) else { return }
            if !requests.isEmpty { again = true }
            for request in requests {
                guard self.lease?.id == lease.id else { return }
                let reply = await handler(request.command)
                try? await AgentIO.run { try CLIWriteTransport.respond(reply, id: request.id, at: root) }
            }
        } while again && self.lease?.id == lease.id
    }
}
