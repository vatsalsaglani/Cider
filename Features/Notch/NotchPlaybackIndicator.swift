import SwiftUI
import CiderUI

/// Mounted only during playback; its timeline updates independently of the HUD.
struct NotchPlaybackIndicator: View {
    let motionActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animating: Bool { motionActive && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !animating)) { context in
            Canvas { drawing, size in
                let time = animating ? context.date.timeIntervalSinceReferenceDate : 0
                for bar in 0..<5 {
                    let phase = Double(bar) * 1.7
                    let height = 2 + (sin(time * 7 + phase) + 1) * 4
                    let rect = CGRect(x: Double(bar) * 2.5, y: (size.height - height) / 2,
                                      width: 1.5, height: height)
                    drawing.fill(Path(roundedRect: rect, cornerRadius: 0.75),
                                 with: .color(CiderColor.accent))
                }
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityLabel("Music playing")
    }
}
