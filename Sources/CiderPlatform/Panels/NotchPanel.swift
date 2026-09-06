import AppKit

@MainActor
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CapturePanel: NSPanel {
    var cancel: (() -> Void)?
    var lostFocus: (() -> Void)?
    override func resignKey() { super.resignKey(); lostFocus?() }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { cancel?() }
}
