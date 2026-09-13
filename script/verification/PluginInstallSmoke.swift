import Foundation
import CiderData
import CiderDomain

@main struct PluginInstallSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { fatalError("Usage: plugin-install-smoke APP FIXTURE_ROOT") }
        let bundle = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let root = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var environment = ProcessInfo.processInfo.environment
        for (key, folder) in [("CODEX_HOME", "codex-home"), ("CLAUDE_CONFIG_DIR", "claude-home")] {
            let path = root.appending(path: folder)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            environment[key] = path.path
        }
        let setup = AgentPluginSetup(base: root.appending(path: "AgentPlugins"), bundle: bundle, environment: environment)
        for provider in [TrackedProvider.codex, .claude] {
            guard let executable = AgentPluginSetup.executable(provider) else { fatalError("Missing \(provider.title) executable") }
            let plan = try await setup.preview(provider, executable: executable)
            precondition(!plan.state.installed)
            try await setup.apply(plan)
            let status = try await setup.state(provider, executable: executable)
            precondition(status.installed && status.enabled)
            let manifest = bundle.appending(path: "Contents/Resources/agent-plugins/\(provider.rawValue)/plugins/cider/\(provider == .codex ? ".codex-plugin" : ".claude-plugin")/plugin.json")
            let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: Any]
            let version = metadata["version"] as! String
            let cache = root.appending(path: provider == .codex ? "codex-home" : "claude-home")
                .appending(path: "plugins/cache/cider-bundled/cider/\(version)")
            let skill = try String(contentsOf: cache.appending(path: "skills/workflow/SKILL.md"), encoding: .utf8)
            precondition(skill.contains("note append") && skill.contains("--if-revision"))
            let launcher = cache.appending(path: "scripts/cider")
            let help = try await PluginProcess.run(launcher, ["--help"], environment: environment)
            precondition(String(decoding: help, as: UTF8.self).contains("note append"))
            let reinstall = try await setup.preview(provider, executable: executable)
            try await setup.apply(reinstall)
            let removal = try await setup.preview(provider, executable: executable, removing: true)
            try await setup.apply(removal)
            let removed = try await setup.state(provider, executable: executable)
            precondition(!removed.installed)
            print("PASS: \(provider.title) isolated install, enabled status, packaged CLI launcher, reinstall and removal")
        }
    }
}
