import Foundation

public enum UsageDisplayMode: String, CaseIterable, Sendable {
    case used, remaining
    public var title: String { rawValue.capitalized }
    public func percent(for quota: Quota) -> Double? {
        quota.validUsedPercent.map { self == .used ? $0 : 100 - $0 }
    }
}

public struct UsagePace: Sendable {
    public enum State: Sendable { case enough, tight, runningOut, exhausted, unknown }
    public let state: State
    public let note: String
    public let projectedUsedAtReset: Double?
    public let estimatedExhaustion: Date?
    public let hourlyPercent: Double?
    public var warning: Bool { [.tight, .runningOut, .exhausted].contains(state) }

    public static func estimate(quota: Quota, observedAt: Date?, now: Date) -> Self {
        func unknown(_ note: String) -> Self { Self(state: .unknown, note: note, projectedUsedAtReset: nil, estimatedExhaustion: nil, hourlyPercent: nil) }
        guard let used = quota.validUsedPercent else { return unknown("Usage not reported") }
        guard let observedAt, (-60...1200).contains(now.timeIntervalSince(observedAt)) else { return unknown("Refresh to estimate pace") }
        guard let reset = quota.resetDate else { return unknown("Reset time unavailable") }
        guard reset > now else { return unknown("Reset passed · refreshing soon") }
        guard let minutes = quota.windowMinutes, (1...525600).contains(minutes) else { return unknown("Window length unavailable") }
        let duration = Double(minutes) * 60
        let elapsed = observedAt.timeIntervalSince(reset.addingTimeInterval(-duration))
        guard elapsed >= 900, elapsed <= duration else { return unknown("Too early to estimate pace") }
        let rate = used / elapsed
        let projected = rate * duration
        let exhausted = rate > 0 ? observedAt.addingTimeInterval((100 - used) / rate) : nil
        let state: State
        let note: String
        if used >= 100 { state = .exhausted; note = "Limit reached · wait for reset" }
        else if projected > 100 {
            state = .runningOut
            note = exhausted.map { $0 > now ? "May run out in " + durationLabel($0.timeIntervalSince(now)) : "May be at limit · refresh" } ?? "May run out before reset"
        } else if projected >= 95 { state = .tight; note = "Tight · near the limit at reset" }
        else { state = .enough; note = "On pace · ~\(Int((100 - projected).rounded()))% spare at reset" }
        return Self(state: state, note: note, projectedUsedAtReset: projected, estimatedExhaustion: exhausted, hourlyPercent: rate * 3600)
    }

    public static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(max(0, seconds) / 60)))
        if minutes >= 1440 { return "\(minutes / 1440)d \((minutes % 1440) / 60)h" }
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}
