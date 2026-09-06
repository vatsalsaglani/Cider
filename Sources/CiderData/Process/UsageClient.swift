import Foundation
import CiderDomain

public enum UsageFailure: Error, Sendable {
    case authentication, unavailable, timedOut, rateLimited, cliMissing
    public var message: String {
        switch self {
        case .authentication: "The usage connection could not access your sign-in. Agent activity can still work. Try Automatic or check /usage in the agent."
        case .timedOut: "Usage took too long to respond. Cider will retry automatically."
        case .rateLimited: "Usage requests are temporarily limited. Cider will retry later."
        case .cliMissing: "The agent command line could not be found. Install it or choose Agent sign-in."
        case .unavailable: "Usage could not be read. Agent activity can still work. Check /usage in the agent; Cider will retry automatically."
        }
    }
}

public enum UsageClient {
    public static func isProbeDirectory(_ path: String) -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/CodexBar/ClaudeProbe")
        return URL(fileURLWithPath: path).standardizedFileURL == probe.standardizedFileURL
    }
    public typealias Run = @Sendable (String, [String], TimeInterval, [String: String]) async throws -> Data
    public static func fetch(path: String, provider: String, source: String,
                             run: Run = { try await CommandRunner.run($0, arguments: $1, timeout: $2, environment: $3) }) async throws -> ProviderUsage {
        // Explicit sources avoid the helper's browser-cookie discovery in its auto mode.
        let sources = source == "automatic" ? ["oauth", "cli"] : [source]
        var failure = UsageFailure.unavailable
        for candidate in sources {
            try Task.checkCancellation()
            do {
                let data = try await run(path, ["usage", "--provider", provider, "--source", candidate, "--format", "json", "--no-credits"], candidate == "cli" ? 75 : 45, environment(provider: provider, base: ProcessInfo.processInfo.environment))
                var value = try decode(data, provider: provider)
                value.source = candidate
                return value
            } catch is CancellationError { throw CancellationError() }
            catch CommandFailure.timedOut { failure = .timedOut }
            catch let error as UsageFailure {
                failure = error
                if case .rateLimited = error { throw error }
            } catch { failure = .unavailable }
        }
        throw failure
    }
    public static func environment(provider: String, base: [String: String]) -> [String: String] {
        guard provider == "claude" else { return base }
        // These are subscription quotas. A launching terminal may instead be configured for
        // Bedrock/Vertex/Foundry or a custom API endpoint; keep the user's configuration intact.
        let routing = Set(["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY", "CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CODE_OAUTH_SCOPES"])
        return base.filter { !routing.contains($0.key) && !$0.key.hasPrefix("ANTHROPIC_") }
    }
    public static func decode(_ data: Data, provider: String) throws -> ProviderUsage {
        let values = try JSONDecoder().decode([ProviderUsage].self, from: data)
        if let value = values.first(where: { $0.provider == provider }), !value.quotas.isEmpty { return value }
        // Never expose or persist raw helper errors (which may contain account details).
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        let error = rows?.first(where: { $0["provider"] as? String == provider })?["error"] as? [String: Any]
        let message = (error?["message"] as? String ?? "").lowercased()
        if ["rate limit", "rate_limit", "429"].contains(where: message.contains) { throw UsageFailure.rateLimited }
        if ["credential", "keychain", "unauthorized", "expired", "authentication", "scope", "login"].contains(where: message.contains) { throw UsageFailure.authentication }
        if ["timed out", "timeout", "still loading"].contains(where: message.contains) { throw UsageFailure.timedOut }
        if message.contains("not installed") || message.contains("not found") { throw UsageFailure.cliMissing }
        throw UsageFailure.unavailable
    }
}
