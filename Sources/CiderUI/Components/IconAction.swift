import SwiftUI

public struct IconAction: View {
    let label: String
    let symbol: String
    let primary: Bool
    let action: () -> Void
    public init(_ label: String, symbol: String, primary: Bool = false, action: @escaping () -> Void) {
        self.label = label; self.symbol = symbol; self.primary = primary; self.action = action
    }
    public var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32).contentShape(RoundedRectangle(cornerRadius: 11)) }
            .buttonStyle(CiderIconStyle(primary: primary)).help(label).accessibilityLabel(label)
    }
}
struct CiderIconStyle: ButtonStyle {
    var primary: Bool
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primary ? CiderColor.accentEnd : CiderColor.textPrimary)
            .background(LinearGradient(colors: [Color.white.opacity(primary ? 0.12 : 0.07), CiderColor.accent.opacity(primary ? 0.17 : 0.035)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.09)))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .opacity(enabled ? (configuration.isPressed ? 0.6 : 1) : 0.35)
    }
}
