import AppKit
import Observation
import CiderDomain
import CiderData

@MainActor @Observable
final class AgentTrackingModel {
    var sessions: [TrackedSession] = []
    var now = Date.now
    var error: String?
    var proposal: HookProposal?
    var busy = false
    var versions: [TrackedProvider: String] = [:]
    var configured = Set(UserDefaults.standard.stringArray(forKey: "trackingProviders") ?? [])
    @ObservationIgnored var onNotice: ((AgentNotice) -> Void)?
    @ObservationIgnored var onUsageStop: ((Set<TrackedProvider>) -> Void)?
    @ObservationIgnored var onSourceOpened: (() -> Void)?
    private var loadedActivity = false
    @ObservationIgnored var openWorkspace: (() -> Void)?
    @ObservationIgnored private var watcher: (any DispatchSourceFileSystemObject)?
    @ObservationIgnored private var clock: Task<Void, Never>?
    private var reading = false
    private var again = false
    @ObservationIgnored private var titles: [String: String] = [:]
    @ObservationIgnored private var titleSessions: Set<String> = []
    @ObservationIgnored private var titleCheckedAt = Date.distantPast
    @ObservationIgnored private var readingTitles = false
    private let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Cider/Tracking")
    var active: [TrackedSession] { sessions.filter { $0.execution != .ended } }
    var attentionCount: Int { active.filter { $0.needsAttention(at: now) }.count }
    var hasConnectedAgents: Bool {
        TrackedProvider.allCases.contains { configured.contains($0.rawValue) }
            || active.contains { !$0.stale(at: now) }
    }
    func start() async {
        guard clock == nil else { return }
        await refresh()
        Task { await discoverVersions() }
        let fd = open(root.appending(path: "spool").path, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            source.setEventHandler { [weak self] in Task { @MainActor in await self?.refresh() } }
            source.setCancelHandler { close(fd) }
            watcher = source; source.resume()
        }
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.now = .now
                await self?.refreshTitles()
            }
        }
    }
    func stop() { watcher?.cancel(); watcher = nil; clock?.cancel(); clock = nil }
    func refresh() async {
        if reading { again = true; return }
        reading = true
        repeat {
            again = false
            let root = root
            do {
                let ledger = try await AgentIO.run { try AgentEventStore.ingest(root: root) }
                // The bundled /usage probe is not user work and must not trigger a refresh loop.
                let observed = ledger.sessions.values.filter { !UsageClient.isProbeDirectory($0.directory) }.map { row in
                    var row = row
                    if row.provider == .codex { row.title = titles[row.session] }
                    return row
                }
                now = .now
                if loadedActivity {
                    let previous = Set(sessions.flatMap { $0.history.map(\.id) })
                    let stopped = UsageRefreshSchedule.stoppedProviders(events: observed.flatMap(\.history), known: previous, now: now)
                    if !stopped.isEmpty { onUsageStop?(stopped) }
                    if let notice = AgentNotice.latest(sessions: observed, known: previous, now: now) { onNotice?(notice) }
                }
                loadedActivity = true
                sessions = observed.sorted {
                    if $0.needsAttention(at: now) != $1.needsAttention(at: now) { return $0.needsAttention(at: now) }
                    return $0.updated > $1.updated
                }
                await refreshTitles()
            } catch { self.error = "Tracking could not be refreshed. Saved activity has been kept." }
        } while again
        reading = false
    }
    private func refreshTitles() async {
        let ids = Set(sessions.filter { $0.provider == .codex }.map(\.session))
        guard !readingTitles, ids != titleSessions || Date.now.timeIntervalSince(titleCheckedAt) >= 30 else { return }
        readingTitles = true
        defer { readingTitles = false }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appending(path: ".codex")
        let index = codexHome.appending(path: "session_index.jsonl")
        do {
            titles = try await AgentIO.run { try CodexSessionTitles.load(index: index, sessions: ids) }
        } catch {
            // Title discovery must never interrupt activity or discard a previously observed name.
            titles = titles.filter { ids.contains($0.key) }
        }
        titleSessions = ids; titleCheckedAt = .now
        sessions = sessions.map { row in
            var row = row
            if row.provider == .codex { row.title = titles[row.session] }
            return row
        }
    }
    func prepare(_ provider: TrackedProvider, removing: Bool = false) {
        guard !busy else { return }; busy = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        let env = ProcessInfo.processInfo.environment
        let configRoot = env[provider == .codex ? "CODEX_HOME" : "CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) } ?? home.appending(path: provider == .codex ? ".codex" : ".claude")
        let destination = configRoot.appending(path: provider == .codex ? "hooks.json" : "settings.json")
        let helper = home.appending(path: "Library/Application Support/Cider/Helpers/cider-events")
        Task {
            defer { busy = false }
            do { proposal = try await AgentIO.run { try AgentHookSetup.propose(provider: provider, destination: destination, helper: helper, removing: removing) } }
            catch { self.error = "Settings could not be prepared. Check the configuration file; nothing has been changed." }
        }
    }
    func apply() {
        guard let proposal, !busy else { return }; busy = true
        let bundled = Bundle.main.bundleURL.appending(path: "Contents/Helpers/cider-events")
        Task {
            defer { busy = false }
            do {
                try await AgentIO.run { try AgentHookSetup.apply(proposal, bundledHelper: bundled) }
                if proposal.removing { configured.remove(proposal.provider.rawValue) } else { configured.insert(proposal.provider.rawValue) }
                UserDefaults.standard.set(Array(configured), forKey: "trackingProviders")
                self.proposal = nil
            } catch { self.error = "Settings changed or could not be saved. Review the connection again before retrying."; self.proposal = nil }
        }
    }
    private func discoverVersions() async {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for provider in TrackedProvider.allCases {
            let name = provider.rawValue
            let candidates = [home + "/.local/bin/" + name, "/opt/homebrew/bin/" + name, "/usr/local/bin/" + name] + (provider == .codex ? ["/Applications/Codex.app/Contents/Resources/codex", "/Applications/ChatGPT.app/Contents/Resources/codex"] : [])
            guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { continue }
            if let output = try? await CommandRunner.run(executable, arguments: ["--version"], timeout: 4) {
                versions[provider] = String(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            }
        }
    }
    func connection(_ provider: TrackedProvider) -> String {
        if sessions.contains(where: { $0.provider == provider && !$0.stale(at: now) }) { return "Receiving activity" }
        return configured.contains(provider.rawValue) ? "Awaiting activity · start a new session" : "Not configured in Cider"
    }
    func openSource(_ row: TrackedSession) {
        guard let origin = row.history.last(where: { $0.origin != nil })?.origin else {
            error = "The source app is not known for this session yet. Send another message from its terminal or editor to capture it."; return
        }
        guard let app = NSRunningApplication(processIdentifier: origin.processID), app.bundleIdentifier == origin.bundleID,
              app.launchDate == origin.launched else {
            error = "The original " + origin.name + " process is no longer running. Cider won’t open a different session."; return
        }
        if let url = AgentDestination.taskURL(provider: row.provider, session: row.session, origin: origin), let bundle = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: bundle, configuration: configuration) { [weak self] _, failure in
                let failed = failure != nil
                Task { @MainActor in
                    guard let self else { return }
                    if failed { self.error = "Codex could not open this task. The session ID is available to copy." }
                    else { self.onSourceOpened?() }
                }
            }
        } else if app.activate() { onSourceOpened?() }
    }
}
