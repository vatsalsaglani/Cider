import Foundation
import Observation
import CiderDomain

@MainActor @Observable
public final class UsageMonitor {
    public typealias Fetch = @Sendable (String, String, String) async throws -> ProviderUsage
    public var path = ""
    public private(set) var enabledProviders: Set<String>
    public var source: String { didSet { if oldValue != source { connectionChanged() } } }
    public var displayMode: UsageDisplayMode { didSet { defaults.set(displayMode.rawValue, forKey: "usageDisplayMode") } }
    public private(set) var refreshing: Set<String> = []
    public var busy: Bool { !refreshing.isEmpty }
    public private(set) var values: [String: ProviderUsage] = [:]
    public private(set) var messages: [String: String] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let date: () -> Date
    @ObservationIgnored private let automaticScheduling: Bool
    @ObservationIgnored private var schedules: [String: UsageRefreshSchedule] = [:]
    @ObservationIgnored private var requests: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var generations: [String: UUID] = [:]
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var running = false

    public init(defaults: UserDefaults = .standard, automaticScheduling: Bool = true,
                date: @escaping () -> Date = { .now },
                fetch: @escaping Fetch = { try await UsageClient.fetch(path: $0, provider: $1, source: $2) }) {
        self.defaults = defaults; self.automaticScheduling = automaticScheduling; self.date = date; self.fetch = fetch
        displayMode = UsageDisplayMode(rawValue: defaults.string(forKey: "usageDisplayMode") ?? "used") ?? .used
        enabledProviders = Set(defaults.stringArray(forKey: "usageProviders") ?? ["codex", "claude"]).intersection(["codex", "claude"])
        // The old default forced OAuth for both agents. Migrate to automatic fallback once.
        let saved = defaults.string(forKey: "usageConnectionMode") ?? (defaults.string(forKey: "usageSource") == "cli" ? "cli" : "automatic")
        source = ["automatic", "oauth", "cli"].contains(saved) ? saved : "automatic"
    }
    public func discover() {
        let bundled = Bundle.main.bundleURL.appending(path: "Contents/Helpers/CodexBarCLI").path
        path = FileManager.default.isExecutableFile(atPath: bundled) ? bundled : ""
        if path.isEmpty { for provider in enabledProviders { messages[provider] = "Usage is missing from this installation. Please reinstall Cider." } }
    }
    public func start() {
        guard !running else { return }
        if path.isEmpty { discover() }
        running = true; armTimer()
    }
    public func stop() {
        running = false; timer?.cancel(); timer = nil
        for provider in Array(requests.keys) { cancel(provider) }
    }
    public func setEnabled(_ provider: String, _ enabled: Bool) {
        guard ["codex", "claude"].contains(provider) else { return }
        if enabled { enabledProviders.insert(provider); schedules[provider] = UsageRefreshSchedule() }
        else { enabledProviders.remove(provider); cancel(provider) }
        defaults.set(Array(enabledProviders), forKey: "usageProviders")
        armTimer()
    }
    public func receivedStop(_ providers: Set<TrackedProvider>) {
        for provider in providers.map(\.rawValue) where enabledProviders.contains(provider) {
            schedules[provider, default: UsageRefreshSchedule()].receivedStop(at: date())
        }
        armTimer()
    }
    public func refresh() async { await refresh(providers: enabledProviders) }
    public func refreshIfDue() async {
        guard running else { return }
        let now = date()
        let due = enabledProviders.filter { (schedules[$0] ?? UsageRefreshSchedule()).next.map { $0 <= now } ?? false }
        await refresh(providers: due)
    }
    private func refresh(providers: Set<String>) async {
        guard !path.isEmpty else { return }
        var jobs: [Task<Void, Never>] = []
        for provider in providers.sorted() where enabledProviders.contains(provider) {
            if let existing = requests[provider] { jobs.append(existing); continue }
            guard schedules[provider, default: UsageRefreshSchedule()].begin(at: date()) else { continue }
            let generation = UUID(), path = path, source = source, fetch = fetch
            generations[provider] = generation; refreshing.insert(provider)
            messages[provider] = nil
            let task = Task { [weak self] in
                var result: ProviderUsage?, failure: UsageFailure?
                do { result = try await fetch(path, provider, source) }
                catch is CancellationError { failure = .unavailable }
                catch let error as UsageFailure { failure = error }
                catch { failure = .unavailable }
                guard let self, !Task.isCancelled, self.generations[provider] == generation else { return }
                if let result { self.values[provider] = result }
                self.messages[provider] = failure?.message
                self.refreshing.remove(provider); self.requests[provider] = nil
                self.schedules[provider, default: UsageRefreshSchedule()].finish(at: self.date(), succeeded: result != nil)
                self.armTimer()
            }
            requests[provider] = task; jobs.append(task)
        }
        armTimer()
        for job in jobs { await job.value }
    }
    private func cancel(_ provider: String) {
        generations[provider] = nil; requests.removeValue(forKey: provider)?.cancel()
        refreshing.remove(provider); schedules[provider]?.cancel()
    }
    private func connectionChanged() {
        defaults.set(source, forKey: "usageConnectionMode")
        for provider in enabledProviders {
            cancel(provider); schedules[provider] = UsageRefreshSchedule()
            values[provider] = nil; messages[provider] = nil
        }
        armTimer()
    }
    private func armTimer() {
        timer?.cancel(); timer = nil
        guard running, automaticScheduling, !path.isEmpty,
              let next = enabledProviders.compactMap({ (schedules[$0] ?? UsageRefreshSchedule()).next }).min() else { return }
        let delay = max(0.05, next.timeIntervalSince(date()))
        timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.refreshIfDue()
        }
    }
}
