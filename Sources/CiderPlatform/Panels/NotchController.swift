import AppKit
import SwiftUI
import Observation
import CiderDomain

@MainActor @Observable
public final class NotchPresentation {
    public var peekTitle: String?
    public var peekMessage = ""
    public var activatePeek: (() -> Void)?
    public var expanded = false
    public var pinned = false
    public var available = false
    public var capturing = false
    public var dismissCapture: (() -> Void)?
    public var cameraWidth: CGFloat = 0
    public var headerHeight: CGFloat = 32
    public var edge = NotchEdge.top
    public init() {}
}

@MainActor
public final class NotchController {
    public let presentation = NotchPresentation()
    private let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var capture: CapturePanel?
    private var preferences = NotchPreferences()
    private var previousApp: NSRunningApplication?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var monitors: [Any] = []
    private var transition: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var peekRequiresInput = false
    private var pointerInside = false
    private let captureContent: (@escaping () -> Void) -> AnyView

    public init(content: (NotchPresentation, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void) -> AnyView,
                captureContent: @escaping (@escaping () -> Void) -> AnyView) {
        self.captureContent = captureContent
        presentation.dismissCapture = { [weak self] in self?.closeCapture(restoreFocus: false) }
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: content(presentation,
            { [weak self] in self?.toggle() },
            { [weak self] in self?.togglePin() },
            { [weak self] in self?.beginCapture() }).preferredColorScheme(.dark))
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
    }

    public func start(preferences: NotchPreferences) {
        self.preferences = preferences
        guard observers.isEmpty else { refresh(); return }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification)
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            let clicked = event.type == .leftMouseDown || event.type == .rightMouseDown
            Task { @MainActor [weak self] in self?.handlePointer(clicked: clicked) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            self?.handlePointer(clicked: event.type == .leftMouseDown || event.type == .rightMouseDown)
            return event
        }) { monitors.append(monitor) }
        refresh()
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        observers.append((center, token))
    }
    public func update(preferences: NotchPreferences) {
        self.preferences = preferences
        transition?.cancel(); closeCapture(); refresh()
    }
    public func stop() {
        peekTask?.cancel(); presentation.peekTitle = nil; presentation.activatePeek = nil
        transition?.cancel(); transition = nil
        closeCapture(restoreFocus: false); transition?.cancel(); panel.orderOut(nil)
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        monitors.forEach(NSEvent.removeMonitor); monitors.removeAll()
    }
    public func peek(title: String, message: String, requiresInput: Bool = false, action: (() -> Void)? = nil) {
        guard !presentation.expanded, !presentation.capturing else { return }
        guard requiresInput || presentation.peekTitle == nil || !peekRequiresInput else { return }
        transition?.cancel(); peekTask?.cancel()
        peekRequiresInput = requiresInput
        presentation.peekTitle = title; presentation.peekMessage = message; presentation.activatePeek = action
        refresh()
        peekTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self else { return }
            presentation.peekTitle = nil; presentation.activatePeek = nil; refresh()
        }
    }
    public func dismissAfterSourceOpen() {
        transition?.cancel(); peekTask?.cancel()
        closeCapture(restoreFocus: false)
        transition?.cancel()
        presentation.peekTitle = nil; presentation.activatePeek = nil
        presentation.pinned = false; presentation.expanded = false
        refresh()
    }
    public func toggle() {
        peekTask?.cancel(); presentation.peekTitle = nil; presentation.activatePeek = nil
        transition?.cancel()
        if presentation.capturing { closeCapture() }
        presentation.expanded.toggle()
        if !presentation.expanded { presentation.pinned = false }
        refresh()
    }
    private func togglePin() {
        transition?.cancel(); presentation.pinned.toggle(); presentation.expanded = true; refresh()
    }
    private func refresh() {
        guard preferences.enabled, let (_, display) = BuiltinDisplay.resolve() else {
            presentation.available = false; closeCapture(); panel.orderOut(nil); return
        }
        presentation.available = true; presentation.edge = preferences.edge
        presentation.cameraWidth = preferences.edge == .top ? display.cameraWidth : 0
        presentation.headerHeight = preferences.edge == .top ? max(32, display.cameraHeight) : 32
        var frame = NotchGeometry.frame(display: display, edge: preferences.edge,
                                          expanded: presentation.expanded || presentation.peekTitle != nil, position: preferences.position)
        if presentation.peekTitle != nil && !presentation.expanded {
            let height = presentation.headerHeight + 82
            if preferences.edge == .top { frame.origin.y = frame.maxY - height }
            frame.size.height = height
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        positionCapture()
    }
    private func handlePointer(clicked: Bool) {
        if clicked, let capture, !capture.frame.contains(NSEvent.mouseLocation) {
            closeCapture(restoreFocus: false)
        }
        trackPointer()
    }
    private func trackPointer() {
        guard panel.isVisible else { return }
        let point = NSEvent.mouseLocation
        let local = CGPoint(x: point.x - panel.frame.minX, y: panel.frame.maxY - point.y)
        let bounds = CGRect(origin: .zero, size: panel.frame.size)
        let shape = NotchOutline.path(in: bounds, edge: preferences.edge)
        let inside = shape.contains(local)
        panel.ignoresMouseEvents = !inside
        guard inside != pointerInside else { return }
        pointerInside = inside; transition?.cancel()
        guard !presentation.pinned, !presentation.capturing, presentation.peekTitle == nil else { return }
        if inside && preferences.hover && !presentation.expanded { schedule(expand: true, milliseconds: 250) }
        else if !inside && presentation.expanded { schedule(expand: false, milliseconds: 450) }
    }
    private func schedule(expand: Bool, milliseconds: Int) {
        transition = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(milliseconds)) } catch { return }
            guard let self, !presentation.pinned, !presentation.capturing else { return }
            presentation.expanded = expand; refresh()
        }
    }
    private func beginCapture() {
        guard presentation.available else { return }
        transition?.cancel(); presentation.expanded = true; presentation.capturing = true
        refresh()
        if let capture { capture.makeKeyAndOrderFront(nil); return }
        previousApp = NSWorkspace.shared.frontmostApplication
        let capture = CapturePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        capture.isOpaque = false; capture.backgroundColor = .clear; capture.hasShadow = false
        capture.hidesOnDeactivate = false; capture.level = .statusBar; capture.isReleasedWhenClosed = false
        capture.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        capture.cancel = { [weak self] in self?.closeCapture() }
        capture.lostFocus = { [weak self] in self?.closeCapture(restoreFocus: false) }
        capture.contentView = NSHostingView(rootView: captureContent { [weak self] in self?.closeCapture() }.preferredColorScheme(.dark))
        self.capture = capture
        panel.addChildWindow(capture, ordered: .above)
        positionCapture(); capture.makeKeyAndOrderFront(nil)
    }
    private func positionCapture() {
        guard let capture else { return }
        capture.setFrame(CGRect(x: panel.frame.minX + 26, y: panel.frame.minY + 60,
                                width: panel.frame.width - 52, height: 54), display: true)
    }
    private func closeCapture(restoreFocus: Bool = true) {
        guard let capture else { presentation.capturing = false; return }
        let restore = restoreFocus && capture.isKeyWindow
        capture.lostFocus = nil; capture.cancel = nil
        panel.removeChildWindow(capture); capture.orderOut(nil)
        capture.contentView = nil; self.capture = nil; presentation.capturing = false
        if restore { previousApp?.activate() }
        previousApp = nil
        // Capture may have suppressed the only pointer-exit event. Reconcile even
        // when the pointer has not moved since the editing lease ended.
        pointerInside = true
        trackPointer()
    }
}
