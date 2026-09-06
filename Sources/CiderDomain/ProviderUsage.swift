import Foundation

public struct Quota: Decodable, Identifiable, Sendable {
    public var id = ""
    public var label = ""
    public let usedPercent: Double?
    public let windowMinutes: Int?
    public let resetsAt: String?
    public let resetDescription: String?
    public var resetDate: Date? { UsageDate.parse(resetsAt) }
    public var validUsedPercent: Double? { usedPercent.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil } }
    public init(id: String = "", label: String = "", usedPercent: Double?, windowMinutes: Int? = nil, resetsAt: String? = nil, resetDescription: String? = nil) {
        self.id = id; self.label = label; self.usedPercent = usedPercent; self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt; self.resetDescription = resetDescription
    }
    enum CodingKeys: String, CodingKey { case usedPercent, windowMinutes, resetsAt, resetDescription }
    public var shortLabel: String {
        guard let minutes = windowMinutes else { return label }
        if label.hasPrefix("Codex Spark") { return "Spark " + Self.period(minutes) }
        guard ["primary", "secondary"].contains(id) else { return label }
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
    public struct NamedWindow: Decodable, Sendable { public let id: String; public let title: String; public let window: Quota }
    public struct Windows: Decodable, Sendable {
        public let primary: Quota?; public let secondary: Quota?; public let tertiary: Quota?; public let quaternary: Quota?
        public let extraRateWindows: [NamedWindow]?
        public let updatedAt: String?
    }
    public var observedAt: Date? { UsageDate.parse(usage?.updatedAt) }
    public var quotas: [Quota] {
        var rows: [Quota] = [("primary", "Session", usage?.primary), ("secondary", "Weekly", usage?.secondary), ("tertiary", "Model limit", usage?.tertiary), ("quaternary", "Additional", usage?.quaternary)].compactMap { id, label, quota in
            guard var quota else { return nil }; quota.id = id; quota.label = label; return quota
        }
        var seen = Set(rows.map(\.id))
        for named in (usage?.extraRateWindows ?? []).prefix(16) {
            let id = String(named.id.prefix(150))
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            var quota = named.window; quota.id = id
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
        return rows
    }
}

public enum UsageDate {
    public static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return (try? Date(value, strategy: .iso8601)) ?? (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }
}
