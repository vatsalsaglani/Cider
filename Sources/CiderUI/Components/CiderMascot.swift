import SwiftUI
import CiderDomain

/// A sleeping task between brief native transitions, with no per-frame polling or web view.
public struct CiderMascot: View {
    public let state: CiderMascotState
    public let visible: Bool
    public var size: CGFloat
    public let claimBounce: (UUID) -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink: CGFloat = 1
    @State private var gaze: CGFloat = 0
    @State private var lift: CGFloat = 0
    @State private var breathing = false
    @State private var tilt: Double = 0

    public init(state: CiderMascotState, visible: Bool, size: CGFloat = 30, claimBounce: @escaping (UUID) -> Bool) {
        self.state = state; self.visible = visible; self.size = size; self.claimBounce = claimBounce
    }

    public var body: some View {
        CiderMascotArtwork(mood: state.mood, size: size,
                           blink: reduceMotion || !visible ? 1 : blink, gaze: reduceMotion || !visible ? 0 : gaze)
            .scaleEffect(x: breathing && visible && !reduceMotion ? 1.008 : 1,
                         y: breathing && visible && !reduceMotion ? 0.992 : 1, anchor: .bottom)
            .offset(y: reduceMotion || !visible ? 0 : lift * size / 512)
            .rotationEffect(.degrees(state.mood == .working ? (reduceMotion || !visible ? -7 : tilt) : 0))
            .help("Cider · " + state.label)
            .accessibilityHidden(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cider")
            .accessibilityValue(state.label)
            .task(id: MotionKey(mood: state.mood, reply: state.replyID, enabled: visible && !reduceMotion)) {
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { blink = 1; gaze = 0; lift = 0; breathing = false; tilt = 0 }
                guard visible, !reduceMotion else { return }
                do {
                    if let id = state.replyID {
                        if claimBounce(id) {
                            withAnimation(.easeOut(duration: 0.16)) { lift = -12 }
                            try await Task.sleep(for: .milliseconds(160))
                            withAnimation(.spring(duration: 0.32, bounce: 0.2)) { lift = 0 }
                        }
                        return // Happy eyes persist only for the brief response cue; the bounce never loops.
                    }
                    if state.mood == .working {
                        // Start immediately: sub-point eye movements alone disappear at notch size.
                        var right = true
                        var beats = 0
                        while !Task.isCancelled {
                            withAnimation(.easeInOut(duration: 0.85)) {
                                tilt = right ? -7 : 7
                                gaze = right ? -14 : 14
                            }
                            try await Task.sleep(for: .milliseconds(850))
                            try Task.checkCancellation()
                            beats += 1
                            if beats.isMultiple(of: 4) {
                                withAnimation(.linear(duration: 0.08)) { blink = 0.09 }
                                try await Task.sleep(for: .milliseconds(100))
                                withAnimation(.easeOut(duration: 0.14)) { blink = 1 }
                            }
                            right.toggle()
                        }
                        return
                    }
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(6.7))
                        try Task.checkCancellation()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            breathing = state.mood == .idle
                        }
                        withAnimation(.linear(duration: 0.08)) { blink = 0.09 }
                        try await Task.sleep(for: .milliseconds(100))
                        withAnimation(.easeOut(duration: 0.14)) { blink = 1 }
                        try await Task.sleep(for: .milliseconds(400))
                        withAnimation(.easeInOut(duration: 0.45)) { breathing = false }
                    }
                } catch { /* SwiftUI cancels motion on disappearance, mood change, or visibility change. */ }
            }
    }
}

private struct MotionKey: Equatable {
    let mood: CiderMascotMood
    let reply: UUID?
    let enabled: Bool
}
