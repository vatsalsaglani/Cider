import SwiftUI
import CiderData
import CiderUI

/// Review-only entry point. App wiring and packaged resource discovery are owned by Plan 09.
struct AgentAccessView: LinkedAgentAccessFeature {
    @State private var provider: WorkflowSkillProvider = .codex

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Agent access").font(.title2.weight(.semibold))
            Text("Install the Cider workflow skill only after reviewing its project-local destination and exact command.")
                .foregroundStyle(.secondary)
            CiderPillPicker("Workflow provider", selection: $provider, options: WorkflowSkillProvider.allCases, title: providerTitle)
                .frame(maxWidth: 300)
            GroupBox("Packaged skill required") {
                Text("This source build does not assume a bundled Cider executable or a chosen project. When the packaged app is available, choose a project and review install, update, or remove before any file changes.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
            }
            Text("No global settings, hooks, or provider credentials are changed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .accessibilityElement(children: .contain)
    }

    private func providerTitle(_ provider: WorkflowSkillProvider) -> String {
        provider == .codex ? "Codex" : "Claude Code"
    }
}
