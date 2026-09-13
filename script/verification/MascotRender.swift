import AppKit
import SwiftUI
import CiderDomain
import CiderUI

/// Offscreen native rendering evidence, independent of screen capture or UI automation.
@main struct MascotRender {
    @MainActor static func main() throws {
        let content = VStack(spacing: 24) {
            Text("Cider · native expressions").font(.title2.weight(.semibold))
            HStack(spacing: 24) {
                ForEach(CiderMascotMood.allCases, id: \.rawValue) { mood in
                    VStack {
                        CiderMascotArtwork(mood: mood, size: 128)
                        Text(mood.rawValue).font(.caption)
                    }
                }
            }
            HStack(spacing: 32) {
                Text("Notch size").font(.caption)
                ForEach(CiderMascotMood.allCases, id: \.rawValue) { mood in CiderMascotArtwork(mood: mood, size: 30) }
            }
        }.padding(32).foregroundStyle(.white).background(Color(red: 0.055, green: 0.05, blue: 0.045))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.coderInvalidValue)
        }
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Rendered native expressions: \(image.width) × \(image.height)")
    }
}
