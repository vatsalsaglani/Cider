import Foundation
import Testing
@testable import CiderData
import CiderDomain

struct AgentPluginSetupTests {
    @Test func installReinstallAndRemoveUseProviderCommandsAndPortableLauncher() async throws {
        for provider in [TrackedProvider.codex, .claude] {
            let fixture = try Fixture(provider); defer { fixture.close() }
            let plan = try await fixture.setup.preview(provider, executable: fixture.providerCLI)
            #expect(!FileManager.default.fileExists(atPath: plan.destination.path))
            #expect(plan.commands.contains(["plugin", "marketplace", "add", plan.destination.path]))
            try await fixture.setup.apply(plan)
            #expect(try await fixture.setup.state(provider, executable: fixture.providerCLI).enabled)
            let launcher = plan.destination.appending(path: "plugins/cider/scripts/cider")
            let output = try await PluginProcess.run(launcher, ["literal $(do-not-run)"])
            #expect(String(decoding: output, as: UTF8.self) == "literal $(do-not-run)\n")
            let reinstall = try await fixture.setup.preview(provider, executable: fixture.providerCLI)
            #expect(reinstall.commands.count == 2)
            try await fixture.setup.apply(reinstall)
            let removal = try await fixture.setup.preview(provider, executable: fixture.providerCLI, removing: true)
            try await fixture.setup.apply(removal)
            #expect(try await !fixture.setup.state(provider, executable: fixture.providerCLI).installed)
            #expect(FileManager.default.fileExists(atPath: plan.destination.path))
        }
    }
    @Test func changedProviderStateAndEditedPayloadAreNotOverwritten() async throws {
        let f = try Fixture(.codex); defer { f.close() }
        let plan = try await f.setup.preview(.codex, executable: f.providerCLI)
        try Data().write(to: f.root.appending(path: "installed"))
        await #expect(throws: WorkStoreError.conflict) { try await f.setup.apply(plan) }
        try FileManager.default.removeItem(at: f.root.appending(path: "installed"))
        try await f.setup.apply(plan)
        let edited = plan.destination.appending(path: "plugins/cider/skills/workflow/SKILL.md")
        try Data("User edit".utf8).write(to: edited)
        await #expect(throws: WorkStoreError.conflict) { _ = try await f.setup.preview(.codex, executable: f.providerCLI) }
        #expect(try String(contentsOf: edited, encoding: .utf8) == "User edit")
        // Removing via the provider remains possible without deleting edited source files.
        let remove = try await f.setup.preview(.codex, executable: f.providerCLI, removing: true)
        try await f.setup.apply(remove)
        #expect(try String(contentsOf: edited, encoding: .utf8) == "User edit")
    }
    @Test func failedProviderExitDoesNotReportSuccessAndCanBeRetried() async throws {
        let f = try Fixture(.claude); defer { f.close() }
        try Data().write(to: f.root.appending(path: "fail-install"))
        let plan = try await f.setup.preview(.claude, executable: f.providerCLI)
        await #expect(throws: PluginProcessError.self) { try await f.setup.apply(plan) }
        #expect(try await !f.setup.state(.claude, executable: f.providerCLI).installed)
        try FileManager.default.removeItem(at: f.root.appending(path: "fail-install"))
        let retry = try await f.setup.preview(.claude, executable: f.providerCLI)
        #expect(!retry.commands.contains(where: { $0.starts(with: ["plugin", "marketplace", "add"]) }))
        try await f.setup.apply(retry)
    }
    @Test func unrelatedMarketplaceAndSymlinkedPayloadAreRefused() async throws {
        let f = try Fixture(.claude); defer { f.close() }
        let wrong = Data(#"[{"name":"cider-bundled","path":"/unrelated"}]"#.utf8)
        try wrong.write(to: f.root.appending(path: "market-present.json"))
        try Data().write(to: f.root.appending(path: "registered"))
        await #expect(throws: WorkStoreError.conflict) { _ = try await f.setup.preview(.claude, executable: f.providerCLI) }
        try FileManager.default.removeItem(at: f.root.appending(path: "registered"))
        try FileManager.default.createDirectory(at: f.base, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: f.base.appending(path: "claude"), withDestinationURL: f.root)
        await #expect(throws: WorkStoreError.outsideRoot) { _ = try await f.setup.preview(.claude, executable: f.providerCLI) }
    }

    private struct Fixture {
        let root: URL
        let base: URL
        let providerCLI: URL
        let setup: AgentPluginSetup
        init(_ provider: TrackedProvider) throws {
            root = URL.temporaryDirectory.appending(path: "cider-plugin-test-' " + UUID().uuidString).resolvingSymlinksInPath()
            base = root.appending(path: "managed")
            providerCLI = root.appending(path: "agent")
            let bundle = root.appending(path: "Cider.app")
            let source = bundle.appending(path: "Contents/Resources/agent-plugins/" + provider.rawValue)
            let skill = source.appending(path: "plugins/cider/skills/workflow/SKILL.md")
            try FileManager.default.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("Synthetic workflow".utf8).write(to: skill)
            let cli = bundle.appending(path: "Contents/Helpers/cider")
            try FileManager.default.createDirectory(at: cli.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/sh\nprintf '%s\\n' \"$@\"\n".utf8).write(to: cli)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
            let schema = bundle.appending(path: "Contents/Resources/Cider_CiderData.bundle/Schema.sql")
            try FileManager.default.createDirectory(at: schema.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("Synthetic schema".utf8).write(to: schema)
            let destination = base.appending(path: provider.rawValue).path
            let market: [[String: Any]] = [["name": "cider-bundled", provider == .codex ? "root" : "path": destination]]
            let plugin: [[String: Any]] = [[provider == .codex ? "pluginId" : "id": AgentPluginSetup.selector, "enabled": true, "scope": "user"]]
            let documents: [String: Any] = [
                "market-present": provider == .codex ? ["marketplaces": market] : market,
                "market-empty": provider == .codex ? ["marketplaces": []] : [],
                "plugin-present": provider == .codex ? ["installed": plugin] : plugin,
                "plugin-empty": provider == .codex ? ["installed": []] : []]
            for (name, data) in documents { try JSONSerialization.data(withJSONObject: data).write(to: root.appending(path: name + ".json")) }
            let script = #"""
            #!/bin/sh
            set -eu
            if [ "$2" = marketplace ]; then
              if [ "$3" = add ]; then /usr/bin/touch "$FIXTURE_ROOT/registered"; exit 0; fi
              if [ -f "$FIXTURE_ROOT/registered" ]; then /bin/cat "$FIXTURE_ROOT/market-present.json"; else /bin/cat "$FIXTURE_ROOT/market-empty.json"; fi
            elif [ "$2" = list ]; then
              if [ -f "$FIXTURE_ROOT/installed" ]; then /bin/cat "$FIXTURE_ROOT/plugin-present.json"; else /bin/cat "$FIXTURE_ROOT/plugin-empty.json"; fi
            elif [ "$2" = add ] || [ "$2" = install ]; then
              if [ -f "$FIXTURE_ROOT/fail-install" ]; then printf 'success-looking output'; exit 9; fi
              /usr/bin/touch "$FIXTURE_ROOT/installed"
            elif [ "$2" = remove ] || [ "$2" = uninstall ]; then /bin/rm "$FIXTURE_ROOT/installed"
            else exit 8
            fi
            """#
            try Data(script.utf8).write(to: providerCLI)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: providerCLI.path)
            setup = AgentPluginSetup(base: base, bundle: bundle, environment: ["FIXTURE_ROOT": root.path, "PATH": "/usr/bin:/bin"])
        }
        func close() { try? FileManager.default.removeItem(at: root) }
    }
}
