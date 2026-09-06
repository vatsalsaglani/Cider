import SwiftUI

public struct UsageRing: View {
    let percent: Double?
    let warning: Bool
    let size: CGFloat
    let label: String
    public init(percent: Double?, warning: Bool = false, size: CGFloat = 44, label: String) {
        self.percent = percent; self.warning = warning; self.size = size; self.label = label
    }
    public var body: some View {
        ZStack {
            Circle().stroke(CiderColor.usageTrack.opacity(0.7), lineWidth: 4)
            if let percent {
                Circle().trim(from: 0, to: min(1, max(0, percent / 100)))
                    .stroke(warning ? CiderColor.warning : CiderColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(size: size < 44 ? 10 : 13, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(percent == nil ? CiderColor.textDisabled : CiderColor.textPrimary)
        }.frame(width: size, height: size).padding(2)
            .accessibilityElement(children: .ignore).accessibilityLabel(label)
            .accessibilityValue(percent.map { "\(Int($0.rounded())) percent" } ?? "Not reported")
    }
}
