import Foundation

public enum AgentDestination {
    /// Verified against the installed Codex desktop's copy-link and URL router.
    /// Terminal-hosted Codex sessions must continue to open their terminal.
    public static func taskURL(provider: TrackedProvider, session: String, origin: AgentOrigin) -> URL? {
        guard provider == .codex, origin.bundleID == "com.openai.codex", UUID(uuidString: session) != nil else { return nil }
        var parts = URLComponents()
        parts.scheme = "codex"; parts.host = "threads"; parts.path = "/" + session
        return parts.url
    }
}
