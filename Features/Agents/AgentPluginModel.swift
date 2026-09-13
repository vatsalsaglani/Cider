import Foundation
import Observation
import CiderData
import CiderDomain

@MainActor @Observable
final class AgentPluginModel {
    var states: [TrackedProvider: AgentPluginState] = [:]
    var messages: [TrackedProvider: String] = [:]
    var proposal: AgentPluginPlan?
    var busy = false
    private let fixtureMode = ProcessInfo.processInfo.environment["CIDER_LINKED_FIXTURE_ROOT"] != nil
    private let setup = AgentPluginSetup(
        base: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Cider/AgentPlugins"),
        bundle: Bundle.main.bundleURL)

    func refresh() async {
        guard !fixtureMode, !busy else { return }
        busy = true; defer { busy = false }
        for provider in [TrackedProvider.codex, .claude] {
            guard let executable = AgentPluginSetup.executable(provider) else {
                messages[provider] = "Install the agent’s command-line app to manage its Cider plugin."; continue
            }
            do {
                states[provider] = try await setup.state(provider, executable: executable)
                messages[provider] = nil
            } catch { states[provider] = nil; messages[provider] = "Plugin status unavailable. Check that the agent supports plugin management." }
        }
    }
    func status(_ provider: TrackedProvider) -> String {
        if let message = messages[provider] { return message }
        guard let state = states[provider] else { return "Plugin status not checked" }
        return state.installed ? (state.enabled ? "Cider plugin installed" : "Cider plugin disabled in agent") : "Cider plugin not installed"
    }
    func prepare(_ provider: TrackedProvider, removing: Bool = false) async -> AgentPluginPlan? {
        guard !fixtureMode, !busy, let executable = AgentPluginSetup.executable(provider) else { return nil }
        busy = true; defer { busy = false }
        do {
            let plan = try await setup.preview(provider, executable: executable, removing: removing)
            messages[provider] = nil
            return plan
        } catch WorkStoreError.notFound {
            messages[provider] = "Cider plugin not installed"
            return nil
        } catch {
            messages[provider] = "Plugin setup is unavailable or conflicts with an existing Cider marketplace. No plugin changes were made."
            return nil
        }
    }
    func review(_ provider: TrackedProvider, removing: Bool = false) {
        Task { proposal = await prepare(provider, removing: removing) }
    }
    func apply(_ plan: AgentPluginPlan) async {
        guard !fixtureMode, !busy else { return }
        busy = true
        do {
            try await setup.apply(plan)
            states[plan.provider] = try await setup.state(plan.provider, executable: plan.executable)
            messages[plan.provider] = plan.removing ? "Plugin removed. Restart agent sessions to unload it." : "Plugin installed. Start a new agent session to use Cider."
        } catch {
            states[plan.provider] = try? await setup.state(plan.provider, executable: plan.executable)
            messages[plan.provider] = "Plugin setup did not finish. Tracking is unchanged. Refresh status and review setup to retry; the marketplace may already be registered."
        }
        proposal = nil; busy = false
    }
}
