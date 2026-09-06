import AppKit
import Testing
@testable import CiderPlatform

@Test @MainActor func captureReleasesOnFocusLossAndEscape() {
    _ = NSApplication.shared
    let panel = CapturePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    var lostFocus = 0
    var cancelled = 0
    panel.lostFocus = { lostFocus += 1 }
    panel.cancel = { cancelled += 1 }
    panel.resignKey()
    #expect(lostFocus == 1)
    panel.cancelOperation(nil)
    #expect(cancelled == 1)
    panel.lostFocus = nil
    panel.resignKey()
    #expect(lostFocus == 1)
}
