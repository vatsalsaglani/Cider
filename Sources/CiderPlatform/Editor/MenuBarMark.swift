import AppKit
import SwiftUI

/// Status items need an intrinsically small image, not a resizable SwiftUI artwork view.
public struct MenuBarMark: View {
    public init() {}
    private static let icon: NSImage? = {
        let url = Bundle.main.bundleURL.appending(path: "Contents/Resources/Cider_CiderPlatform.bundle/Resources/branding/cider.png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
    public var body: some View {
        if let icon = Self.icon { Image(nsImage: icon).accessibilityLabel("Cider") }
        else { Image(systemName: "circle.hexagongrid").accessibilityLabel("Cider") }
    }
}
