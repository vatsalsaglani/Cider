import SwiftUI
import CiderDomain
import CiderPlatform

struct AgentConnectionsView: View {
    @Bindable var model: AgentTrackingModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect your agents to see their activity in Cider.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    ForEach(TrackedProvider.allCases) { provider in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { BrandImage(provider.rawValue); Text(provider.title).font(.headline) }
                            if provider == .cursor { Text("Local Cursor sessions").font(.caption).foregroundStyle(.secondary) }
                            if let version = model.versions[provider] {
                                Text(version).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(model.connection(provider)).font(.caption).foregroundStyle(.secondary)
                            Button(model.configured.contains(provider.rawValue) ? "Disconnect" : "Connect") {
                                model.prepare(provider, removing: model.configured.contains(provider.rawValue))
                            }.disabled(model.busy || model.plugins.busy)
                            if provider != .cursor { AgentPluginControls(model: model.plugins, provider: provider).disabled(model.busy) }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                Text("Start a new session after connecting. Cursor activity covers work on this Mac. Connect usage separately in Usage.")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Grok Bot", systemImage: "sparkles").font(.headline)
                    Text("Enable Cursor & Grok Bot in Usage to see the Bot allowance reported by your account. Live Bot activity and response peeks aren’t available yet; you can keep a Bot link in its task or note.")
                        .font(.callout).foregroundStyle(.secondary)
                    Link("About Grok Bot", destination: URL(string: "https://x.ai/bot")!)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                Divider()
                HStack {
                    Text("Cider plugin lets your agent work with tasks and notes you request.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh plugins") { Task { await model.plugins.refresh() } }.disabled(model.busy || model.plugins.busy)
                }
                DisclosureGroup("Project-only workflow skill (alternative)") { AgentAccessView().frame(minHeight: 400) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await model.plugins.refresh() }
        .sheet(item: Binding(get: { model.plugins.proposal }, set: { model.plugins.proposal = $0 })) { plan in
            AgentPluginReviewSheet(model: model.plugins, plan: plan)
        }
    }
}
