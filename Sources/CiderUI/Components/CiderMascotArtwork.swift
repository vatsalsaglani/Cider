import SwiftUI
import CiderDomain

/// Native rendering of the supplied cider-*-still.svg artwork, in its 512-point coordinates.
/// The paper silhouette and fold stay fixed while the expression can move independently.
public struct CiderMascotArtwork: View {
    public let mood: CiderMascotMood
    public var size: CGFloat
    public var blink: CGFloat
    public var gaze: CGFloat
    public init(mood: CiderMascotMood = .idle, size: CGFloat = 26, blink: CGFloat = 1, gaze: CGFloat = 0) {
        self.mood = mood; self.size = size; self.blink = blink; self.gaze = gaze
    }
    public var body: some View {
        ZStack(alignment: .topLeading) {
            MascotPaper()
            ForEach([CGFloat(158), 314], id: \.self) { x in
                Group {
                    if mood == .replyReady {
                        HappyEye().stroke(ink(0x26140f), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 35, height: 29).offset(x: x, y: 260)
                    } else {
                        RoundedRectangle(cornerRadius: 17.5)
                            .fill(LinearGradient(colors: [ink(0x382017), ink(0x21110e), ink(0x140c0a)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 35, height: 64)
                            .scaleEffect(x: 1, y: mood == .needsYou && x == 314 ? 1.15 : blink * (mood == .working ? 0.75 : 1))
                            .offset(x: x + gaze, y: mood == .needsYou ? 245 : 250)
                    }
                }
            }
        }
        .frame(width: 512, height: 512)
        .scaleEffect(size / 512)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addCurve(to: CGPoint(x: rect.width, y: rect.height),
                   control1: CGPoint(x: 3, y: 0), control2: CGPoint(x: rect.width - 4, y: 0))
        return p
    }
}

private struct MascotPaper: View {
    var body: some View {
        Canvas { context, _ in
            let body = paperPath
            context.fill(body, with: .linearGradient(Gradient(stops: [
                .init(color: ink(0xffe58b), location: 0), .init(color: ink(0xffbb47), location: 0.37),
                .init(color: ink(0xff8a21), location: 0.72), .init(color: ink(0xc9440e), location: 1)
            ]), startPoint: CGPoint(x: 146, y: 103), endPoint: CGPoint(x: 368, y: 400)))
            context.fill(body, with: .radialGradient(Gradient(stops: [
                .init(color: ink(0xfff4b7).opacity(0.64), location: 0),
                .init(color: ink(0xffd66e).opacity(0.08), location: 0.65),
                .init(color: .clear, location: 1)
            ]), center: CGPoint(x: 169, y: 161), startRadius: 0, endRadius: 283))
            context.clip(to: body)
            context.drawLayer { shadow in
                shadow.addFilter(.blur(radius: 4))
                shadow.fill(foldShadow, with: .color(ink(0x8a3009).opacity(0.33)))
            }
            context.fill(foldPath, with: .linearGradient(Gradient(stops: [
                .init(color: ink(0xfff4c2), location: 0), .init(color: ink(0xffdb80), location: 0.5),
                .init(color: ink(0xffb847), location: 0.88), .init(color: ink(0xed781b), location: 1)
            ]), startPoint: CGPoint(x: 310, y: 79), endPoint: CGPoint(x: 357, y: 179)))
            var highlight = Path()
            highlight.move(to: CGPoint(x: 292, y: 80))
            curve(&highlight, to: (307, 153), c1: (304, 96), c2: (300, 133))
            context.stroke(highlight, with: .color(ink(0xfff4ce).opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }.frame(width: 512, height: 512)
    }

    private var paperPath: Path {
        var p = Path(); p.move(to: CGPoint(x: 274, y: 77))
        curve(&p, to: (317, 93), c1: (293, 75), c2: (303, 80))
        p.addLine(to: CGPoint(x: 382, y: 155))
        curve(&p, to: (437, 253), c1: (411, 180), c2: (428, 216))
        curve(&p, to: (426, 378), c1: (450, 300), c2: (452, 350))
        curve(&p, to: (252, 420), c1: (397, 411), c2: (322, 421))
        curve(&p, to: (80, 379), c1: (173, 420), c2: (105, 410))
        curve(&p, to: (70, 264), c1: (55, 347), c2: (62, 299))
        curve(&p, to: (153, 128), c1: (84, 201), c2: (111, 159))
        curve(&p, to: (274, 77), c1: (190, 101), c2: (232, 82))
        p.closeSubpath(); return p
    }
    private var foldPath: Path {
        var p = Path(); p.move(to: CGPoint(x: 292, y: 79))
        curve(&p, to: (309, 158), c1: (309, 91), c2: (299, 139))
        curve(&p, to: (382, 177), c1: (321, 177), c2: (354, 164))
        curve(&p, to: (317, 107), c1: (374, 164), c2: (340, 131))
        curve(&p, to: (292, 79), c1: (307, 96), c2: (300, 86))
        p.closeSubpath(); return p
    }
    private var foldShadow: Path {
        var p = Path(); p.move(to: CGPoint(x: 296, y: 87))
        curve(&p, to: (313, 174), c1: (310, 112), c2: (295, 161))
        curve(&p, to: (391, 186), c1: (333, 189), c2: (365, 175))
        p.addLine(to: CGPoint(x: 397, y: 199))
        curve(&p, to: (307, 188), c1: (363, 179), c2: (330, 205))
        curve(&p, to: (291, 91), c1: (289, 174), c2: (303, 125))
        p.closeSubpath(); return p
    }
}

private func curve(_ path: inout Path, to: (CGFloat, CGFloat), c1: (CGFloat, CGFloat), c2: (CGFloat, CGFloat)) {
    path.addCurve(to: CGPoint(x: to.0, y: to.1), control1: CGPoint(x: c1.0, y: c1.1), control2: CGPoint(x: c2.0, y: c2.1))
}
private func ink(_ hex: UInt32) -> Color {
    Color(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
}
