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
                ForEach(UsageProvider.allCases.map(\.rawValue), id: \.self) { provider in
                    UsageProviderCard(provider: provider, value: model.values[provider], mode: model.displayMode,
                                      enabled: model.enabledProviders.contains(provider), refreshing: model.refreshing.contains(provider), message: model.messages[provider])
                }
                Text("Refreshes every 10 minutes and after agent responses.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Connection settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(UsageProvider.allCases.map(\.rawValue), id: \.self) { provider in
                            Toggle(UsageProvider(rawValue: provider)?.title ?? provider, isOn: Binding(get: { model.enabledProviders.contains(provider) }, set: { model.setEnabled(provider, $0) }))
                            Text(UsageProvider(rawValue: provider)?.connectionDetail ?? "").font(.caption).foregroundStyle(.secondary)
                        }

                        Text("Usage is provided by CodexBar, included with Cider.").font(.caption).foregroundStyle(.secondary)
                        Picker("Codex, Claude and Grok Build connection", selection: $model.source) { Text("Automatic").tag("automatic"); Text("Agent sign-in").tag("oauth"); Text("Agent command line").tag("cli") }
                    }.padding(.top, 12)
                }
            }.padding(32)
        }.task { model.start() }
    }
}
