import AppKit
import SwiftUI
import CiderUI

/// Status items need an intrinsically small image, not a resizable SwiftUI artwork view.
public struct MenuBarMark: View {
    public init() {}
    private static let icon: NSImage? = {
        guard let image = CiderBrandAssets.mascot?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
    public var body: some View {
        if let icon = Self.icon { Image(nsImage: icon).accessibilityLabel("Cider") }
        else { CiderMascotArtwork(size: 18).accessibilityHidden(false).accessibilityLabel("Cider") }
    }
}
