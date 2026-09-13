import AppKit
import SwiftUI
import CiderUI

/// Synthetic native layout preview; no screen capture or user data.
@main struct DialogRender {
    @MainActor static func main() throws {
        let content = VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                CiderDialogHeading("Install Cider plugin", symbol: "puzzlepiece.extension")
                Text("Add Cider tasks, notes and linked-work commands to Codex for your account across projects.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your agent can work with tasks and notes you request. Keep Cider open to save changes.")
                    .font(.caption).foregroundStyle(CiderColor.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Installation details", systemImage: "chevron.down").font(.subheadline.weight(.medium))
                    Text("~/Library/Application Support/Cider/AgentPlugins/codex\n\ncodex plugin add cider@cider-bundled")
                        .font(.caption.monospaced()).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CiderColor.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack { Button("Cancel") {}; Spacer(); Button("Install plugin") {}.buttonStyle(CiderDialogButtonStyle(primary: true)) }
            }.padding(28).frame(width: 560).ciderDialog()
            CiderPrompt(title: "Note needs attention", message: "The saved note changed. Your draft has been kept so you can review both versions.", confirmTitle: "Got it") {}
        }.padding(28).background(CiderColor.surface).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content); renderer.scale = 2
        guard let image = renderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Rendered shared native dialogs: \(image.width) × \(image.height)")
    }
}
