import Foundation

/// Local host provenance captured by the helper, never from hook stdin.
public struct AgentOrigin: Codable, Sendable, Equatable {
    public let bundleID: String
    public let processID: Int32
    public let launched: Date
    public let name: String
    public init(bundleID: String, processID: Int32, launched: Date, name: String) {
        self.bundleID = bundleID; self.processID = processID; self.launched = launched; self.name = name
    }
}
