import Foundation
import Testing
import CiderDomain
import CiderData

@Suite struct ExpandedUsageTests {
    private let cursor = Data(#"[{"provider":"cursor","source":"web","usage":{"primary":{"usedPercent":26,"windowMinutes":43200},"secondary":{"usedPercent":12,"windowMinutes":43200},"tertiary":{"usedPercent":38,"windowMinutes":43200},"extraRateWindows":[{"id":"cursor-grok-bot","title":"Grok Bot","window":{"usedPercent":47,"windowMinutes":10080,"resetsAt":"2026-09-20T00:00:00Z"}}],"identity":{"providerID":"cursor","accountEmail":"fixture@example.invalid","loginMethod":"Cursor Pro"},"updatedAt":"2026-09-13T00:00:00Z"}}]"#.utf8)

    @Test func cursorAndBotUseOneAccountAndIndependentNamedWindows() throws {
        let value = try UsageClient.decode(cursor, provider: "cursor")
        #expect(value.accountLabel == "fixture@example.invalid")
        #expect(value.displayQuotas.map(\.shortLabel) == ["Plan usage", "Cursor models", "Third-party models", "Grok Bot"])
        #expect(value.displayQuotas.map(\.usedPercent) == [26, 12, 38, 47])
        #expect(value.displayQuotas.last?.windowMinutes == 10080)
        #expect(value.displayQuotas.last?.resetDate != nil)
        #expect(throws: UsageFailure.unavailable) { try UsageClient.decode(cursor, provider: "grok") }
    }

    @Test func missingAndExplicitlyUnknownQuotasNeverBecomeZero() throws {
        let absent = try UsageClient.decode(Data(#"[{"provider":"cursor","usage":{"primary":{"usedPercent":0},"identity":{"providerID":"grok","accountEmail":"wrong@example.invalid"}}}]"#.utf8), provider: "cursor")
        #expect(absent.accountLabel == "Current account")
        #expect(absent.displayQuotas.first?.validUsedPercent == 0)
        #expect(absent.displayQuotas.last?.label == "Grok Bot")
        #expect(absent.displayQuotas.last?.validUsedPercent == nil)
        let unknown = try UsageClient.decode(Data(#"[{"provider":"cursor","usage":{"primary":{"usedPercent":0,"isSyntheticPlaceholder":true},"extraRateWindows":[{"id":"cursor-grok-bot","title":"Grok Bot","usageKnown":false,"window":{"usedPercent":100,"windowMinutes":10080}}]}}]"#.utf8), provider: "cursor")
        #expect(unknown.displayQuotas.allSatisfy { $0.validUsedPercent == nil })
    }

    @Test func cursorUsesCodexBarDashboardRegardlessOfCliPreference() async throws {
        let fixture = cursor
        let value = try await UsageClient.fetch(path: "/fixture/CodexBarCLI", provider: "cursor", source: "cli") { path, args, _, _ in
            #expect(path == "/fixture/CodexBarCLI")
            #expect(args == ["usage", "--provider", "cursor", "--source", "auto", "--format", "json", "--no-credits"])
            return fixture
        }
        #expect(value.source == "web")
        #expect(UsageProvider.grok.sources(for: "automatic") == ["oauth", "cli"])
        let grok = try UsageClient.decode(Data(#"[{"provider":"grok","usage":{"primary":{"usedPercent":20,"windowMinutes":43200}}}]"#.utf8), provider: "grok")
        #expect(grok.quotas.first?.shortLabel == "Credits")
        #expect(!grok.displayQuotas.contains { $0.label == "Grok Bot" })
    }

    @Test @MainActor func newConnectionsAreOptInPersistAndRefresh() async throws {
        let suite = "CiderExpandedUsage." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixture = cursor
        let model = UsageMonitor(defaults: defaults, automaticScheduling: false, fetch: { _, provider, _ in
            #expect(provider == "cursor")
            return try UsageClient.decode(fixture, provider: provider)
        })
        #expect(model.enabledProviders == ["codex", "claude"])
        model.setEnabled("codex", false); model.setEnabled("claude", false)
        model.setEnabled("cursor", true)
        model.path = "/fixture"; model.start()
        await model.refreshIfDue()
        #expect(model.values["cursor"]?.quotas.last?.usedPercent == 47)
        #expect(UsageMonitor(defaults: defaults, automaticScheduling: false).enabledProviders == ["cursor"])
        model.stop()
    }
}
