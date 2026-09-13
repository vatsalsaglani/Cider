import Foundation

public struct Quota: Decodable, Identifiable, Sendable {
    public var id = ""
    public var label = ""
    public var usedPercent: Double?
    public let windowMinutes: Int?
    public let resetsAt: String?
    public let resetDescription: String?
    public var resetDate: Date? { UsageDate.parse(resetsAt) }
    public var validUsedPercent: Double? { usedPercent.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil } }
    public init(id: String = "", label: String = "", usedPercent: Double?, windowMinutes: Int? = nil, resetsAt: String? = nil, resetDescription: String? = nil) {
        self.id = id; self.label = label; self.usedPercent = usedPercent; self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt; self.resetDescription = resetDescription
    }
    enum CodingKeys: String, CodingKey { case usedPercent, windowMinutes, resetsAt, resetDescription, isSyntheticPlaceholder }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let placeholder = try container.decodeIfPresent(Bool.self, forKey: .isSyntheticPlaceholder) ?? false
        usedPercent = placeholder ? nil : try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes)
        resetsAt = try container.decodeIfPresent(String.self, forKey: .resetsAt)
        resetDescription = try container.decodeIfPresent(String.self, forKey: .resetDescription)
    }
    public var shortLabel: String {
        guard let minutes = windowMinutes else { return label }
        if label.hasPrefix("Codex Spark") { return "Spark " + Self.period(minutes) }
        guard ["Session", "Weekly"].contains(label), ["primary", "secondary"].contains(id) else { return label }
        return Self.period(minutes)
    }
    private static func period(_ minutes: Int) -> String {
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }
}
public struct ProviderUsage: Decodable, Sendable {
    public let provider: String
    public let account: String?
    public var source: String?
    public let usage: Windows?
    public struct NamedWindow: Decodable, Sendable { public let id: String; public let title: String; public let window: Quota; public let usageKnown: Bool? }
    public struct Identity: Decodable, Sendable {
        public let providerID: String?
        public let accountEmail: String?
        public let loginMethod: String?
    }
    public struct Windows: Decodable, Sendable {
        public let primary: Quota?; public let secondary: Quota?; public let tertiary: Quota?; public let quaternary: Quota?
        public let extraRateWindows: [NamedWindow]?
        public let updatedAt: String?
        public let identity: Identity?
    }
    public var observedAt: Date? { UsageDate.parse(usage?.updatedAt) }
    public var accountLabel: String {
        if let identity = usage?.identity, identity.providerID == provider {
            return identity.accountEmail ?? account ?? identity.loginMethod ?? "Current account"
        }
        return account ?? "Current account"
    }
    public var quotas: [Quota] {
        let labels = UsageProvider(rawValue: provider)?.quotaLabels ?? ["Session", "Weekly", "Model limit", "Additional"]
        var rows: [Quota] = [("primary", labels[0], usage?.primary), ("secondary", labels[1], usage?.secondary), ("tertiary", labels[2], usage?.tertiary), ("quaternary", labels[3], usage?.quaternary)].compactMap { id, label, quota in
            guard var quota else { return nil }; quota.id = id; quota.label = label; return quota
        }
        var seen = Set(rows.map(\.id))
        for named in (usage?.extraRateWindows ?? []).prefix(16) {
            let id = String(named.id.prefix(150))
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            var quota = named.window; quota.id = id
            if named.usageKnown == false { quota.usedPercent = nil }
            quota.label = String(named.title.prefix(60)).components(separatedBy: .controlCharacters).joined(separator: " ")
            rows.append(quota)
        }
        return rows
    }
    public var displayQuotas: [Quota] {
        var rows = quotas
        if provider == "claude", !rows.contains(where: { $0.label.localizedCaseInsensitiveContains("fable") }) {
            rows.append(Quota(id: "fable-unreported", label: "Fable", usedPercent: nil))
        }
        if provider == "cursor", !rows.contains(where: { $0.id == "cursor-grok-bot" }) {
            rows.append(Quota(id: "cursor-grok-bot", label: "Grok Bot", usedPercent: nil))
        }
        return rows
    }
}

public enum UsageDate {
    public static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return (try? Date(value, strategy: .iso8601)) ?? (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }
}
