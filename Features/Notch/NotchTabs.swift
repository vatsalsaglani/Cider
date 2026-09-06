import SwiftUI
import CiderUI

enum NotchTab: String, CaseIterable {
    case agents = "Agents", todo = "TODO", player = "Now Playing", usage = "Usage"
}

struct NotchTabs: View {
    @Binding var selection: NotchTab
    var body: some View {
        CiderPillPicker("Notch tabs", selection: $selection,
                        options: NotchTab.allCases, title: { $0.rawValue })
    }
}
