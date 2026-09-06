import AppKit
import SwiftUI

public struct WindowChrome: NSViewRepresentable {
    public init() {}
    public func makeNSView(context: Context) -> NSView { ChromeView() }
    public func updateNSView(_ view: NSView, context: Context) {}
    final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .black
            window.isMovableByWindowBackground = false
        }
    }
}
