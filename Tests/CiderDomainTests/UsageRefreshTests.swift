import Foundation
import Testing
@testable import CiderDomain
@testable import CiderData

private func usageFixture(_ provider: String, source: String = "cli", percent: Int = 42) throws -> ProviderUsage {
    try UsageClient.decode(usageData(provider, source: source, percent: percent), provider: provider)
}
private func usageData(_ provider: String, source: String = "cli", percent: Int = 42) -> Data {
    Data("[{\"provider\":\"\(provider)\",\"source\":\"\(source)\",\"usage\":{\"primary\":{\"usedPercent\":\(percent),\"windowMinutes\":300},\"updatedAt\":\"2026-09-06T10:00:00Z\"}}]".utf8)
}

@Test func usageScheduleCoalescesStopsAndUsesTenMinutes() {
    let now = Date(timeIntervalSince1970: 10_000)
    var schedule = UsageRefreshSchedule()
    #expect(schedule.next! < now)
    let began = schedule.begin(at: now)
    #expect(began)
    let duplicate = schedule.begin(at: now)
    #expect(!duplicate)
    #expect(schedule.next == nil)
    schedule.finish(at: now.addingTimeInterval(10), succeeded: true)
    #expect(schedule.next == now.addingTimeInterval(610))
    schedule.receivedStop(at: now.addingTimeInterval(20))
    schedule.receivedStop(at: now.addingTimeInterval(21))
    #expect(schedule.next == now.addingTimeInterval(60))
    let followup = schedule.begin(at: now.addingTimeInterval(60))
    #expect(followup)
    schedule.receivedStop(at: now.addingTimeInterval(61))
    schedule.finish(at: now.addingTimeInterval(70), succeeded: true)
    #expect(schedule.next == now.addingTimeInterval(120)) // Stop during a request is retained.
    let trailing = schedule.begin(at: now.addingTimeInterval(120))
    #expect(trailing)
    schedule.finish(at: now.addingTimeInterval(130), succeeded: false)
    schedule.receivedStop(at: now.addingTimeInterval(131))
    #expect(schedule.next == now.addingTimeInterval(730)) // Errors cannot be hammered by hooks.
}

@Test func onlyNewFreshStopEventsRefreshUsage() throws {
    let now = Date.now
    func event(_ name: String, provider: TrackedProvider = .claude, time: Date) throws -> AgentEvent {
        try AgentEvent(provider: provider, payload: Data("{\"session_id\":\"demo\",\"hook_event_name\":\"\(name)\"}".utf8), time: time)
    }
    let known = try event("Stop", time: now)
    let old = try event("Stop", time: now.addingTimeInterval(-100))
    let tool = try event("PostToolUse", time: now)
    let child = try event("SubagentStop", time: now)
    let codex = try event("Stop", provider: .codex, time: now)
    #expect(UsageRefreshSchedule.stoppedProviders(events: [known, old, tool], known: [known.id], now: now).isEmpty)
    #expect(UsageRefreshSchedule.stoppedProviders(events: [known, old, tool, child, codex], known: [known.id], now: now) == [.claude, .codex])
}

private actor AttemptRecorder {
    var sources: [String] = []
    func append(_ source: String) { sources.append(source) }
}
@Test func usageFallsBackWithoutBrowserDiscoveryAndSanitizesErrors() async throws {
    let recorder = AttemptRecorder()
    let result = try await UsageClient.fetch(path: "/fixture", provider: "claude", source: "automatic") { _, args, _, _ in
        let source = args[4]
        await recorder.append(source)
        if source == "oauth" { return Data(#"[{"provider":"claude","error":{"message":"OAuth credentials missing private@example.test"}}]"#.utf8) }
        return usageData("claude")
    }
    #expect(result.quotas.first?.usedPercent == 42)
    #expect(result.source == "cli")
    #expect(await recorder.sources == ["oauth", "cli"])
    await #expect(throws: UsageFailure.rateLimited) {
        try await UsageClient.fetch(path: "/fixture", provider: "claude", source: "automatic") { _, _, _, _ in
            Data(#"[{"provider":"claude","error":{"message":"rate limited 429 private@example.test"}}]"#.utf8)
        }
    }
    #expect(!UsageFailure.authentication.message.contains("private@example.test"))
}

@Test func subscriptionProbeIgnoresInheritedEnterpriseRouting() {
    let base = ["CLAUDE_CODE_USE_BEDROCK":"1", "CLAUDE_CODE_USE_VERTEX":"1", "CLAUDE_CODE_USE_FOUNDRY":"1", "ANTHROPIC_BASE_URL":"https://example.test", "ANTHROPIC_API_KEY":"synthetic", "CLAUDE_CONFIG_DIR":"/chosen/config", "PATH":"/bin"]
    #expect(UsageClient.environment(provider: "claude", base: base) == ["CLAUDE_CONFIG_DIR":"/chosen/config", "PATH":"/bin"])
    #expect(UsageClient.environment(provider: "codex", base: base) == base)
    let probe = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/CodexBar/ClaudeProbe").path
    #expect(UsageClient.isProbeDirectory(probe))
    #expect(!UsageClient.isProbeDirectory("/user/project/ClaudeProbe"))
}

private actor UsageGate {
    private var pending: [String: CheckedContinuation<ProviderUsage, any Error>] = [:]
    private var ready: CheckedContinuation<Void, Never>?
    private var target = 0
    private(set) var calls = 0
    func fetch(_ provider: String) async throws -> ProviderUsage {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending[provider] = continuation
            if pending.count >= target { ready?.resume(); ready = nil }
        }
    }
    func waitFor(_ count: Int) async {
        target = count
        if pending.count >= count { return }
        await withCheckedContinuation { ready = $0 }
    }
    func succeed(_ provider: String, percent: Int = 42) throws {
        pending.removeValue(forKey: provider)?.resume(returning: try usageFixture(provider, percent: percent))
    }
    func fail(_ provider: String) { pending.removeValue(forKey: provider)?.resume(throwing: UsageFailure.timedOut) }
}
@MainActor private final class UsageTestClock {
    var now = Date(timeIntervalSince1970: 10_000)
}

@Test @MainActor func usageProvidersRefreshIndependentlyAndKeepLastGoodValues() async throws {
    let suite = "CiderUsageTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let gate = UsageGate(), clock = UsageTestClock()
    let model = UsageMonitor(defaults: defaults, automaticScheduling: false, date: { clock.now }) { _, provider, _ in try await gate.fetch(provider) }
    model.path = "/fixture"; model.start()
    let first = Task { await model.refreshIfDue() }
    await gate.waitFor(2)
    #expect(model.refreshing == ["codex", "claude"])
    let duplicate = Task { await model.refresh() }
    await Task.yield()
    #expect(await gate.calls == 2)
    try await gate.succeed("codex")
    for _ in 0..<10 where model.refreshing.contains("codex") { await Task.yield() }
    #expect(model.values["codex"] != nil)
    #expect(model.refreshing == ["claude"])
    await gate.fail("claude")
    await first.value; await duplicate.value
    #expect(!model.busy)
    #expect(model.messages["claude"] != nil)
    clock.now.addTimeInterval(600)
    let next = Task { await model.refreshIfDue() }
    await gate.waitFor(2)
    await gate.fail("codex"); try await gate.succeed("claude")
    await next.value
    #expect(model.values["codex"]?.quotas.first?.usedPercent == 42)
    #expect(model.messages["codex"] != nil)
    #expect(model.values["claude"] != nil)
    model.stop()
}

@Test @MainActor func usageStopRefreshTargetsProviderAndDisableRejectsLateResults() async throws {
    let suite = "CiderUsageTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let gate = UsageGate(), clock = UsageTestClock()
    let model = UsageMonitor(defaults: defaults, automaticScheduling: false, date: { clock.now }) { _, provider, _ in try await gate.fetch(provider) }
    model.path = "/fixture"; model.start()
    let first = Task { await model.refreshIfDue() }
    await gate.waitFor(2)
    try await gate.succeed("codex"); try await gate.succeed("claude")
    await first.value
    clock.now.addTimeInterval(60)
    model.receivedStop([.claude]); clock.now.addTimeInterval(3)
    let stopped = Task { await model.refreshIfDue() }
    await gate.waitFor(1)
    #expect(model.refreshing == ["claude"])
    #expect(await gate.calls == 3)
    model.setEnabled("claude", false)
    try await gate.succeed("claude", percent: 90)
    await stopped.value
    #expect(!model.busy)
    #expect(model.values["claude"]?.quotas.first?.usedPercent == 42)
    model.stop()
}

@Test func commandRunnerCancellationDoesNotWaitForDeadline() async {
    let task = Task { try await CommandRunner.run("/bin/sleep", arguments: ["15"], timeout: 20) }
    try? await Task.sleep(for: .milliseconds(100))
    let start = ContinuousClock.now
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(ContinuousClock.now - start < .seconds(2))
}
