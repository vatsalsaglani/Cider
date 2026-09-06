import SwiftUI
import AppKit
import CiderPlatform

@main
struct CiderApp: App {
    @State private var model = AppModel()
    @State private var agents = AgentTrackingModel()
    @State private var usage = UsageModel()
    @State private var notch: NotchController?
    var body: some Scene {
        WindowGroup("Cider", id: "workspace") {
            WorkspaceView(model: model, usage: usage, agents: agents)
                .preferredColorScheme(.dark)
                .task {
                    guard notch == nil else { return }
                    await model.load()
                    agents.onUsageStop = { providers in usage.receivedStop(providers) }
                    usage.start()
                    await agents.start()
                    let controller = NotchController { state, toggle, pin, capture in
                        AnyView(NotchHUDView(model: model, usage: usage, agents: agents, state: state, toggle: toggle, pin: pin, capture: capture))
                    } captureContent: { dismiss in
                        AnyView(NotchCaptureView(model: model, dismiss: dismiss))
                    }
                    agents.onSourceOpened = { [weak controller] in controller?.dismissAfterSourceOpen() }
                    agents.onNotice = { [weak controller] notice in
                        controller?.peek(title: notice.title, message: notice.message, requiresInput: notice.requiresInput, action: { agents.openSource(notice.session) })
                    }
                    notch = controller
                    controller.start(preferences: model.snapshot.notch)
                }
                .onChange(of: model.snapshot.notch) { _, value in notch?.update(preferences: value) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in notch?.stop(); agents.stop(); usage.stop() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in usage.stop() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in usage.start() }
        }.windowStyle(.hiddenTitleBar).defaultSize(width: 1080, height: 740)
        .commands { NoteCommands() }
        MenuBarExtra {
            OpenWorkspaceButton()
            Button("Toggle notch") { notch?.toggle() }
            Divider()
            Button("Quit Cider") { NSApplication.shared.terminate(nil) }
        } label: { MenuBarMark() }
    }
}

struct OpenWorkspaceButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Cider", systemImage: "arrow.up.forward.app") {
            openWindow(id: "workspace")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
