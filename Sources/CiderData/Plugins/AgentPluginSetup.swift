import Foundation
import CiderDomain

public struct AgentPluginState: Sendable, Equatable {
    public var installed: Bool
    public var enabled: Bool
    public var marketplaceRoot: String?
}

public struct AgentPluginPlan: Sendable, Identifiable {
    public let id = UUID()
    public let provider: TrackedProvider
    public let executable: URL
    public let destination: URL
    public let source: URL
    public let cli: URL
    public let removing: Bool
    public let state: AgentPluginState
    public let commands: [[String]]
    public var commandPreview: String {
        commands.map { ([executable.path] + $0).map(Self.quote).joined(separator: " ") }.joined(separator: "\n")
    }
    private static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}

public struct AgentPluginSetup: Sendable {
    public static let selector = "cider@cider-bundled"
    private let base: URL
    private let bundle: URL
    private let environment: [String: String]
    public init(base: URL, bundle: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.base = base.standardizedFileURL.resolvingSymlinksInPath(); self.bundle = bundle; self.environment = environment
    }
    public static func executable(_ provider: TrackedProvider) -> URL? {
        guard provider != .cursor else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [home + "/.local/bin/" + provider.rawValue, "/opt/homebrew/bin/" + provider.rawValue,
                          "/usr/local/bin/" + provider.rawValue] + (provider == .codex ? ["/Applications/Codex.app/Contents/Resources/codex", "/Applications/ChatGPT.app/Contents/Resources/codex"] : [])
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
    public func state(_ provider: TrackedProvider, executable: URL) async throws -> AgentPluginState {
        guard provider != .cursor else { throw WorkStoreError.unavailable }
        let plugins = try await run(executable, ["plugin", "list", "--json"])
        let marketplaces = try await run(executable, ["plugin", "marketplace", "list", "--json"])
        return try Self.parseState(provider, plugins: plugins, marketplaces: marketplaces)
    }
    public static func parseState(_ provider: TrackedProvider, plugins: Data, marketplaces: Data) throws -> AgentPluginState {
        let pluginJSON = try JSONSerialization.jsonObject(with: plugins)
        let marketJSON = try JSONSerialization.jsonObject(with: marketplaces)
        let rows: [[String: Any]]?
        let markets: [[String: Any]]?
        if provider == .codex {
            rows = (pluginJSON as? [String: Any])?["installed"] as? [[String: Any]]
            markets = (marketJSON as? [String: Any])?["marketplaces"] as? [[String: Any]]
        } else { rows = pluginJSON as? [[String: Any]]; markets = marketJSON as? [[String: Any]] }
        guard let rows, let markets else { throw WorkStoreError.unavailable }
        let row = rows.first { ($0[provider == .codex ? "pluginId" : "id"] as? String) == selector && (provider == .codex || ($0["scope"] as? String) == "user") }
        let market = markets.first { ($0["name"] as? String) == "cider-bundled" }
        let path = market?[provider == .codex ? "root" : "path"] as? String
        guard market == nil || path != nil else { throw WorkStoreError.conflict }
        return AgentPluginState(installed: row != nil, enabled: row?["enabled"] as? Bool == true, marketplaceRoot: path)
    }
    public func preview(_ provider: TrackedProvider, executable: URL, removing: Bool = false) async throws -> AgentPluginPlan {
        let state = try await state(provider, executable: executable)
        let destination = base.appending(path: provider.rawValue)
        if let existing = state.marketplaceRoot {
            guard URL(fileURLWithPath: existing).standardizedFileURL.resolvingSymlinksInPath().path == destination.standardizedFileURL.resolvingSymlinksInPath().path else { throw WorkStoreError.conflict }
        }
        var commands: [[String]] = []
        if removing || state.installed {
            commands.append(provider == .codex ? ["plugin", "remove", Self.selector] : ["plugin", "uninstall", Self.selector, "--scope", "user"])
        }
        if !removing {
            if state.marketplaceRoot == nil { commands.append(["plugin", "marketplace", "add", destination.path]) }
            commands.append(provider == .codex ? ["plugin", "add", Self.selector] : ["plugin", "install", Self.selector, "--scope", "user"])
        } else if !state.installed { throw WorkStoreError.notFound }
        let plan = AgentPluginPlan(provider: provider, executable: executable, destination: destination,
                                  source: bundle.appending(path: "Contents/Resources/agent-plugins/" + provider.rawValue),
                                  cli: bundle.appending(path: "Contents/Helpers/cider"), removing: removing, state: state, commands: commands)
        if !removing { try await AgentIO.run { try AgentPluginPayload.validate(plan) } }
        return plan
    }
    public func apply(_ plan: AgentPluginPlan) async throws {
        guard try await state(plan.provider, executable: plan.executable) == plan.state else { throw WorkStoreError.conflict }
        if !plan.removing { try await AgentIO.run { try AgentPluginPayload.stage(plan) } }
        for command in plan.commands { _ = try await run(plan.executable, command) }
        let result = try await state(plan.provider, executable: plan.executable)
        guard plan.removing ? !result.installed : result.installed && result.enabled else { throw WorkStoreError.unavailable }
    }
    private func run(_ executable: URL, _ args: [String]) async throws -> Data {
        try await PluginProcess.run(executable, args, environment: environment)
    }
}
