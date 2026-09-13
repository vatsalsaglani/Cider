import SwiftUI
import CiderDomain
import CiderData
import CiderUI

struct AgentPluginControls: View {
    @Bindable var model: AgentPluginModel
    let provider: TrackedProvider
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.status(provider)).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(model.states[provider]?.installed == true ? "Reinstall plugin…" : "Install Cider plugin…") { model.review(provider) }
                if model.states[provider]?.installed == true {
                    Button("Remove plugin…") { model.review(provider, removing: true) }
                }
            }.disabled(model.busy)
        }
    }
}

struct AgentPluginPlanView: View {
    let plan: AgentPluginPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.removing ? "Remove the Cider plugin from \(plan.provider.title)." : "Add Cider tasks, notes and linked-work commands to \(plan.provider.title) for your account across projects.")
            Text("Your agent can work with tasks and notes you request. Keep Cider open to save changes.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Installation details") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.destination.path).font(.caption.monospaced())
                    Text(plan.commandPreview).font(.caption.monospaced())
                    Text("Removal: use Remove plugin on the agent card. Tracking is managed separately. Local marketplace files are retained for reinstalling.").font(.caption)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CiderColor.surface, in: RoundedRectangle(cornerRadius: 12)).textSelection(.enabled)
            }
        }
    }
}

struct AgentPluginReviewSheet: View {
    @Bindable var model: AgentPluginModel
    let plan: AgentPluginPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CiderDialogHeading(plan.removing ? "Remove Cider plugin" : "Install Cider plugin", symbol: "puzzlepiece.extension")
            ScrollView { AgentPluginPlanView(plan: plan).frame(maxWidth: .infinity, alignment: .leading) }
            HStack {
                Button("Cancel") { model.proposal = nil }.keyboardShortcut(.cancelAction).disabled(model.busy)
                Spacer()
                Button(plan.removing ? "Remove plugin" : "Install plugin") { Task { await model.apply(plan) } }.buttonStyle(CiderDialogButtonStyle(primary: !plan.removing)).disabled(model.busy)
            }
        }.padding(28).frame(width: 560, height: 350).ciderDialog().interactiveDismissDisabled(model.busy)
    }
}

struct AgentConnectionReviewSheet: View {
    @Bindable var model: AgentTrackingModel
    let proposal: HookProposal
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CiderDialogHeading(proposal.removing ? "Disconnect \(proposal.provider.title)" : "Connect \(proposal.provider.title)", symbol: "point.3.connected.trianglepath.dotted")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(proposal.destination.path).font(.caption).textSelection(.enabled)
                    DisclosureGroup("Observer changes") { Text(proposal.preview).font(.caption.monospaced()).textSelection(.enabled) }
                    Text("Cider collects session identifiers, workspace paths and activity names, plus up to 600 characters of each response or question request. Codex chat names come from its local title index. Other prompts, tool inputs and your answers are discarded. Disconnect removes Cider’s observer.").font(.caption)
                    if proposal.provider != .cursor {
                        if let plan = model.connectionPluginPlan {
                            Toggle(proposal.removing ? "Also remove the Cider plugin" : "Also install the Cider plugin", isOn: $model.includeConnectionPlugin)
                            if model.includeConnectionPlugin { AgentPluginPlanView(plan: plan) }
                        } else {
                            Text(model.plugins.status(proposal.provider)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Cancel") { model.proposal = nil }.keyboardShortcut(.cancelAction).disabled(model.busy)
                Spacer()
                Button(proposal.removing ? "Disconnect" : (model.includeConnectionPlugin ? "Connect and install plugin" : "Connect")) { model.apply() }.buttonStyle(CiderDialogButtonStyle(primary: !proposal.removing)).disabled(model.busy)
            }
        }.padding(28).frame(width: 590, height: 450).ciderDialog().interactiveDismissDisabled(model.busy)
    }
}
