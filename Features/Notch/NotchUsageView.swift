import SwiftUI
import CiderDomain
import CiderUI

struct NotchUsageView: View {
    @Bindable var model: UsageModel
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                CiderPillPicker("Show usage as", selection: $model.displayMode,
                                options: UsageDisplayMode.allCases, compact: true, title: { $0.title })
                    .frame(width: 180)
                Spacer()
                IconAction("Refresh usage", symbol: "arrow.clockwise") { Task { await model.refresh() } }
                    .disabled(model.busy || model.path.isEmpty)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(UsageProvider.allCases.map(\.rawValue).filter { model.enabledProviders.contains($0) }, id: \.self) { provider in
                        UsageProviderCard(provider: provider, value: model.values[provider], mode: model.displayMode,
                                          enabled: model.enabledProviders.contains(provider), refreshing: model.refreshing.contains(provider),
                                          message: model.messages[provider], compact: true)
                    }
                }
            }.scrollIndicators(.hidden)
        }.task { model.start() }
    }
}
