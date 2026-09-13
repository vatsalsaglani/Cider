import Foundation

/// Usage capabilities are independent of providers that publish local activity hooks.
public enum UsageProvider: String, CaseIterable, Identifiable, Sendable {
    case codex, claude, cursor, grok
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Code"
        case .cursor: "Cursor & Grok Bot"
        case .grok: "Grok Build"
        }
    }
    public var connectionDetail: String {
        switch self {
        case .codex, .claude: "Uses your existing agent sign-in."
        case .cursor: "CodexBar uses your Cursor app sign-in or cursor.com browser session. Grok Bot appears when your account reports a Bot allowance."
        case .grok: "Uses your Grok Build sign-in. Available quotas depend on your account."
        }
    }
    public func sources(for selection: String) -> [String] {
        // Cursor has a dashboard connection, not an OAuth/CLI quota command.
        if self == .cursor { return ["auto"] }
        return selection == "automatic" ? ["oauth", "cli"] : [selection]
    }
    public var quotaLabels: [String] {
        switch self {
        case .cursor: ["Plan usage", "Cursor models", "Third-party models", "Additional"]
        case .grok: ["Credits", "On-demand", "Model limit", "Additional"]
        case .codex, .claude: ["Session", "Weekly", "Model limit", "Additional"]
        }
    }
}
