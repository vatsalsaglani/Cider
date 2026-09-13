import SwiftUI
import AppKit
import CiderUI

public struct AppMark: View {
    public init() {}
    public var body: some View {
        if let image = CiderBrandAssets.mascot {
            Image(nsImage: image).resizable().scaledToFit().frame(width: 30, height: 30).accessibilityHidden(true)
        } else { CiderMascotArtwork(size: 30) }
    }
}

@MainActor enum CiderBrandAssets {
    static let mascot: NSImage? = {
        // Prefer the installed bundle so packaged apps never depend on a build directory.
        let packaged = Bundle.main.bundleURL.appending(path: "Contents/Resources/Cider_CiderPlatform.bundle/Resources/branding/cider.png")
        if let image = NSImage(contentsOf: packaged) { return image }
        let adjacent = Bundle.main.bundleURL.appending(path: "Cider_CiderPlatform.bundle/Resources/branding/cider.png")
        return NSImage(contentsOf: adjacent)
    }()
}
