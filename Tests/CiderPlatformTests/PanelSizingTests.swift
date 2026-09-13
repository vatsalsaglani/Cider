import AppKit
import SwiftUI
import Testing
@testable import CiderPlatform

@MainActor @Test func panelGeometrySurvivesOversizedContentAndRepeatedTransitions() async throws {
    _ = NSApplication.shared
    let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    let container = PanelContentView(rootView: AnyView(Text("Compact")))
    panel.contentView = container
    panel.orderBack(nil)
    defer { panel.orderOut(nil); panel.contentView = nil }
    for index in 0..<60 {
        let size = index % 3 == 0 ? NSSize(width: 345, height: 32)
            : index % 3 == 1 ? NSSize(width: 440, height: 420) : NSSize(width: 388, height: 54)
        let frame = NSRect(origin: NSPoint(x: 100, y: 100), size: size)
        container.hosting.rootView = AnyView(Text(String(repeating: "Long response\n", count: index + 1))
            .frame(width: 820, height: 1783))
        panel.setFrame(frame, display: false)
        panel.contentView?.updateConstraintsForSubtreeIfNeeded()
        panel.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(20))
        #expect(panel.frame == frame)
        #expect(container.frame.size == size)
        #expect(container.hosting.frame.size == size)
        #expect(container.hosting.sizingOptions.isEmpty)
    }
}
