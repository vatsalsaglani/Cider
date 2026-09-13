import AppKit
import SwiftUI

/// AppKit owns panel geometry. Keep the hosting view out of the window's
/// content-view sizing role so changing SwiftUI content cannot resize the HUD.
@MainActor
final class PanelContentView<Content: View>: NSView {
    let hosting: NSHostingView<Content>

    init(rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.masksToBounds = true
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = bounds
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        addSubview(hosting)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}
