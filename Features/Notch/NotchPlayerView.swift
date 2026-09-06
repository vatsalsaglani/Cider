import SwiftUI
import CiderPlatform
import CiderUI

struct NotchPlayerView: View {
    @Bindable var player: NowPlaying
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Group {
                if let data = player.artwork, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note").font(.system(size: 32)).foregroundStyle(CiderColor.accentEnd)
                }
            }.frame(width: 76, height: 76)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            VStack(spacing: 4) {
                Text(player.title.isEmpty ? "Your music, right here" : player.title).font(.headline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
            if player.canControl {
                HStack(spacing: 20) {
                    IconAction("Previous", symbol: "backward.fill") { player.previous() }
                    IconAction(player.playing ? "Pause" : "Play", symbol: player.playing ? "pause.fill" : "play.fill") { player.togglePlayback() }
                    IconAction("Next", symbol: "forward.fill") { player.next() }
                }
            } else {
                IconAction("Refresh now playing", symbol: "arrow.clockwise") { player.refresh() }
            }
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.playing || reduceMotion)) { context in
                Canvas { drawing, size in
                    let time = player.playing && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0
                    for layer in 0..<3 {
                        var path = Path()
                        for x in stride(from: 0.0, through: size.width, by: 2) {
                            let envelope = sin(x / size.width * .pi)
                            let y = size.height / 2 + sin(x / 18 + time * 3 + Double(layer)) * envelope * (player.playing ? 9 : 2)
                            if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        drawing.stroke(path, with: .color(CiderColor.accentEnd.opacity(0.8 - Double(layer) * 0.2)), lineWidth: 1.5)
                    }
                }
            }.frame(height: 24).accessibilityHidden(true)
            Spacer(minLength: 0)
        }
    }
    private var detail: String {
        if !player.title.isEmpty { return [player.artist, player.source].filter { !$0.isEmpty }.joined(separator: " · ") }
        if player.needsPermission { return "Allow Cider access in System Settings → Privacy → Automation." }
        if player.unavailable { return "Couldn’t read playback. Refresh to try again." }
        return "Play music or a video in your favorite app or browser"
    }
}
