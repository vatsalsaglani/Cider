import SwiftUI
import CiderDomain
import CiderUI
import CiderPlatform
struct UsageView: View {
    @Bindable var model: UsageModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Text("Agent usage").font(.largeTitle.weight(.semibold)); Spacer(); IconAction("Refresh usage", symbol: "arrow.clockwise") { Task { await model.refresh() } }.disabled(model.path.isEmpty || model.busy) }
                CiderPillPicker("Show usage as", selection: $model.displayMode,
                                options: UsageDisplayMode.allCases, title: { $0.title })
                    .frame(width: 230)
                ForEach(["codex", "claude"], id: \.self) { provider in
                    UsageProviderCard(provider: provider, value: model.values[provider], mode: model.displayMode,
                                      enabled: model.enabledProviders.contains(provider), refreshing: model.refreshing.contains(provider), message: model.messages[provider])
                }
                Text("Refreshes every 10 minutes and after agent responses.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Connection settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(["codex", "claude"], id: \.self) { provider in
                            Toggle(provider == "codex" ? "Codex" : "Claude Code", isOn: Binding(get: { model.enabledProviders.contains(provider) }, set: { model.setEnabled(provider, $0) }))
                        }

                        Text("Uses your existing agent sign-in. No extra app is needed.")
                        Picker("Connection", selection: $model.source) { Text("Automatic").tag("automatic"); Text("Agent sign-in").tag("oauth"); Text("Agent command line").tag("cli") }
                    }.padding(.top, 12)
                }
            }.padding(32)
        }.task { model.start() }
    }
}
