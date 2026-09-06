import SwiftUI
import CiderDomain
import CiderUI

struct NotchSettingsView: View {
    @Bindable var model: AppModel
    @State private var preferences = NotchPreferences()
    var body: some View {
        Form {
            Section("Notch") {
                Toggle("Show on MacBook display", isOn: $preferences.enabled)
                Toggle("Open on hover", isOn: $preferences.hover)
                Picker("Placement", selection: $preferences.edge) {
                    ForEach(NotchEdge.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Slider(value: $preferences.position, in: 0...1) { Text("Position along edge") }
                Text("At the top, the notch stays centered around the camera.").foregroundStyle(.secondary)
                HStack { Spacer(); IconAction("Save notch settings", symbol: "checkmark", primary: true) { Task { await model.setNotch(preferences) } }.disabled(model.saving || !model.ready || preferences == model.snapshot.notch) }
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
            .onAppear { preferences = model.snapshot.notch }
    }
}
