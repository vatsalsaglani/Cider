import SwiftUI

/// A compact choice group with the same quiet selection treatment as HUD tabs.
public struct CiderPillPicker<Selection: Hashable>: View {
    @Binding private var selection: Selection
    private let label: String
    private let options: [Selection]
    private let compact: Bool
    private let title: (Selection) -> String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(_ label: String, selection: Binding<Selection>, options: [Selection],
                compact: Bool = false, title: @escaping (Selection) -> String) {
        self.label = label
        self._selection = selection
        self.options = options
        self.compact = compact
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 28 : 32)
                }
                .buttonStyle(PillOptionStyle(selected: selection == option))
                .help(title(option))
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(reduceTransparency ? CiderColor.surfaceRaised : CiderColor.textPrimary.opacity(0.065), in: Capsule())
        .tint(CiderColor.focusRing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

private struct PillOptionStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? CiderColor.textPrimary : CiderColor.textSecondary)
            .background(selected ? selectionFill : .clear, in: Capsule())
            .background(configuration.isPressed ? CiderColor.accent.opacity(0.1) : .clear, in: Capsule())
            .contentShape(Capsule())
    }

    private var selectionFill: Color {
        reduceTransparency ? CiderColor.surfaceHover : CiderColor.textPrimary.opacity(0.14)
    }
}
