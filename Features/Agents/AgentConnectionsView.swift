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
                            if let version = model.versions[provider] {
                                Text(version).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(model.connection(provider)).font(.caption).foregroundStyle(.secondary)
                            Button(model.configured.contains(provider.rawValue) ? "Disconnect" : "Connect") {
                                model.prepare(provider, removing: model.configured.contains(provider.rawValue))
                            }.disabled(model.busy)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                Text("Tracks local Code sessions in Claude Desktop and Claude CLI together. Start a new session after connecting; Codex may ask you to trust the observer.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
