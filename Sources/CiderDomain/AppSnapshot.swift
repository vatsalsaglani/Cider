import Foundation

public struct NotchPreferences: Codable, Equatable, Sendable {
    public var enabled = true
    public var edge = NotchEdge.top
    public var position = 0.5
    public var hover = true
    public init() {}
}

public struct AppSnapshot: Codable, Sendable {
    public var version = 1
    public var tasks: [TaskItem] = []
    public var notch = NotchPreferences()
    public init() {}
}
