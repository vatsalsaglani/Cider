import Foundation

public enum AgentIO {
    private static let queue = DispatchQueue(label: "app.cider.agent-io", qos: .utility)
    public static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try work() }) }
        }
    }
}
