import Foundation

/// One refresh per provider, with a trailing refresh when work stops during a request.
public struct UsageRefreshSchedule: Sendable {
    public static let interval: TimeInterval = 600
    public private(set) var inFlight = false
    private var nextPeriodic = Date.distantPast
    private var pendingStop: Date?
    private var lastStarted = Date.distantPast
    private var retryAfter = Date.distantPast
    private var failures = 0

    public init() {}
    public var next: Date? {
        guard !inFlight else { return nil }
        return max(retryAfter, min(nextPeriodic, pendingStop ?? .distantFuture))
    }
    public mutating func receivedStop(at now: Date) {
        // Batch simultaneous subagents, and cap event-driven polling at once per minute.
        let due = max(now.addingTimeInterval(3), lastStarted.addingTimeInterval(60))
        pendingStop = min(pendingStop ?? due, due)
    }
    public mutating func begin(at now: Date) -> Bool {
        guard !inFlight else { return false }
        inFlight = true; lastStarted = now; pendingStop = nil
        return true
    }
    public mutating func finish(at now: Date, succeeded: Bool) {
        inFlight = false
        nextPeriodic = now.addingTimeInterval(Self.interval)
        failures = succeeded ? 0 : min(failures + 1, 3)
        retryAfter = succeeded ? .distantPast : now.addingTimeInterval(Self.interval * Double(failures))
    }
    public mutating func cancel() { inFlight = false }

    /// Initial replay and old events must not trigger network requests.
    public static func stoppedProviders(events: [AgentEvent], known: Set<UUID>, now: Date) -> Set<TrackedProvider> {
        Set(events.filter {
            ["Stop", "SubagentStop"].contains($0.name) && !known.contains($0.id)
                && (0...60).contains(now.timeIntervalSince($0.time))
        }.map(\.provider))
    }
}
