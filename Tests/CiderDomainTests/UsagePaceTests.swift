import Foundation
import Testing
import CiderDomain
import CiderData

struct UsagePaceTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func quota(_ used: Double?, remainingHours: Double = 1, minutes: Int = 300) -> Quota {
        Quota(id: "primary", label: "Session", usedPercent: used, windowMinutes: minutes,
              resetsAt: now.addingTimeInterval(remainingHours * 3600).ISO8601Format())
    }
    @Test func usedAndRemainingKeepUnknownUnknown() {
        #expect(UsageDisplayMode.used.percent(for: quota(23)) == 23)
        #expect(UsageDisplayMode.remaining.percent(for: quota(23)) == 77)
        #expect(UsageDisplayMode.remaining.percent(for: quota(nil)) == nil)
        #expect(UsageDisplayMode.used.percent(for: quota(101)) == nil)
        #expect(UsageDisplayMode.used.percent(for: quota(-1)) == nil)
        #expect(UsageDisplayMode.used.percent(for: quota(.nan)) == nil)
    }
    @Test func enoughPaceUsesWindowAverage() {
        let pace = UsagePace.estimate(quota: quota(40), observedAt: now, now: now)
        #expect(pace.state == .enough)
        #expect(pace.projectedUsedAtReset == 50)
        #expect(pace.hourlyPercent == 10)
        #expect(pace.note.contains("50% spare"))
        #expect(!pace.warning)
    }
    @Test func warnsBeforeLimitAndNearReset() {
        let risk = UsagePace.estimate(quota: quota(90), observedAt: now, now: now)
        #expect(risk.state == .runningOut)
        #expect(risk.projectedUsedAtReset == 112.5)
        #expect(abs(risk.estimatedExhaustion!.timeIntervalSince(now) - 1600) < 0.001)
        let tight = UsagePace.estimate(quota: quota(79), observedAt: now, now: now)
        #expect(tight.state == .tight)
        #expect(UsagePace.estimate(quota: quota(100), observedAt: now, now: now).state == .exhausted)
    }
    @Test func snapshotAgeCannotCreateArtificiallySlowerRate() {
        let old = now.addingTimeInterval(-600)
        let pace = UsagePace.estimate(quota: quota(40), observedAt: old, now: now)
        #expect(pace.hourlyPercent! > 10) // Uses the observation time, not the later view time.
        let stale = UsagePace.estimate(quota: quota(40), observedAt: now.addingTimeInterval(-1201), now: now)
        #expect(stale.state == .unknown)
        #expect(stale.projectedUsedAtReset == nil)
        #expect(UsagePace.estimate(quota: quota(40), observedAt: now.addingTimeInterval(90), now: now).state == .unknown)
    }
    @Test func missingEarlyAndResetWindowsDoNotForecast() {
        #expect(UsagePace.estimate(quota: quota(nil), observedAt: now, now: now).state == .unknown)
        #expect(UsagePace.estimate(quota: quota(1, remainingHours: 4.9), observedAt: now, now: now).state == .unknown)
        #expect(UsagePace.estimate(quota: quota(50, remainingHours: -1), observedAt: now, now: now).state == .unknown)
        #expect(UsagePace.estimate(quota: quota(50, minutes: 0), observedAt: now, now: now).state == .unknown)
        #expect(UsagePace.estimate(quota: Quota(usedPercent: 10), observedAt: now, now: now).state == .unknown)
        let weekly = UsagePace.estimate(quota: quota(50, remainingHours: 84, minutes: 10080), observedAt: now, now: now)
        #expect(weekly.projectedUsedAtReset == 100)
        #expect(weekly.state == .tight)
    }
    @Test func modelWindowsKeepTheirNamesPercentagesAndResets() throws {
        let fixture = Data(#"[{"provider":"claude","usage":{"primary":{"usedPercent":15,"windowMinutes":300},"secondary":{"usedPercent":30,"windowMinutes":10080},"extraRateWindows":[{"id":"claude-weekly-scoped-fable","title":"Fable only","window":{"usedPercent":62,"windowMinutes":10080,"resetsAt":"2026-09-07T13:00:00.000Z"}},{"id":"claude-weekly-scoped-fable","title":"Duplicate","window":{"usedPercent":90}}],"updatedAt":"2026-09-06T15:00:00.123Z"}}]"#.utf8)
        let value = try UsageClient.decode(fixture, provider: "claude")
        #expect(value.quotas.count == 3)
        #expect(Set(value.quotas.map(\.id)).count == 3)
        let fable = try #require(value.quotas.last)
        #expect(fable.label == "Fable only")
        #expect(fable.usedPercent == 62)
        #expect(fable.resetDate != nil)
        #expect(value.observedAt != nil)
        #expect(value.displayQuotas.count == 3)
    }
    @Test func missingFableHasAnUnknownGaugeInsteadOfZero() throws {
        let value = try UsageClient.decode(Data(#"[{"provider":"claude","usage":{"primary":{"usedPercent":10}}}]"#.utf8), provider: "claude")
        #expect(value.quotas.count == 1)
        let placeholder = try #require(value.displayQuotas.last)
        #expect(placeholder.label == "Fable")
        #expect(placeholder.usedPercent == nil)
        #expect(placeholder.resetsAt == nil)
        #expect(UsageDisplayMode.remaining.percent(for: placeholder) == nil)
    }
    @Test @MainActor func displayPreferencePersistsAndSharesTheMonitor() {
        let suite = "cider-usage-mode-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = UsageMonitor(defaults: defaults, automaticScheduling: false)
        #expect(first.displayMode == .used)
        first.displayMode = .remaining
        let second = UsageMonitor(defaults: defaults, automaticScheduling: false)
        #expect(second.displayMode == .remaining)
        #expect(UsageDisplayMode.remaining.percent(for: quota(40)) == 60)
    }
}
