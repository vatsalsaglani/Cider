import SwiftUI
import AppKit
import CiderPlatform
import CiderDomain
import CiderData

@main
struct CiderApp: App {
    @State private var model = AppModel()
    @State private var agents = AgentTrackingModel()
    @State private var linked = LinkedWorkCoordinator()
    @State private var usage = UsageModel()
    @State private var notch: NotchController?
    private let fixtureRoot = ProcessInfo.processInfo.environment["CIDER_LINKED_FIXTURE_ROOT"]
    init() {
        if let path = ProcessInfo.processInfo.environment["CIDER_LINKED_FIXTURE_ROOT"] {
            let root = URL(fileURLWithPath: path)
            _model = State(initialValue: AppModel(storeURL: root.appending(path: "work.sqlite"),
                legacyURL: root.appending(path: "workspace.json"), folderPaths: [path]))
            _linked = State(initialValue: LinkedWorkCoordinator(notes: NotesModel(folders: [root])))
        }
    }
    var body: some Scene {
        WindowGroup("Cider", id: "workspace") {
            WorkspaceView(model: model, usage: usage, agents: agents, linked: linked)
                .preferredColorScheme(.dark)
                .task {
                    guard notch == nil else { return }
                    await model.load()
                    if let repository = model.repository {
                        do {
                            try await linked.start(repository: repository)
                            agents.journalIngestor = JournalIngestor(repository: repository)
                            agents.journalHostID = linked.hostID
                        }
                        catch { model.error = "Linked work could not be opened. Your saved data has been kept." }
                    }
                    linked.refreshBoard = { await model.refresh() }
                    agents.onSessionsChanged = { rows in await linked.observe(rows) }
                    linked.openChat = { identity in
                        guard let row = agents.sessions.first(where: { $0.provider == identity.provider && $0.session == identity.sessionID && $0.parent == nil }), identity.hostID == linked.hostID else { linked.error = "The original chat is not currently available."; return }
                        agents.openSource(row)
                    }
                    agents.onUsageStop = { providers in usage.receivedStop(providers) }
                    if let fixtureRoot {
                        var ledger = AgentLedger()
                        for index in 1...2 {
                            let payload: [String: String] = ["session_id": "fixture-chat-\(index)", "turn_id": "fixture-turn-\(index)",
                                "hook_event_name": "UserPromptSubmit", "cwd": fixtureRoot]
                            if let data = try? JSONSerialization.data(withJSONObject: payload),
                               let event = try? AgentEvent(provider: .codex, payload: data) { ledger.apply(event) }
                        }
                        agents.sessions = ledger.sessions.values.map { source in
                            var row = source; row.title = "Fixture chat " + String(row.session.suffix(1)); return row
                        }.sorted { $0.session < $1.session }
                        await linked.observe(agents.sessions)
                    } else { usage.start(); await agents.start() }
                    let controller = NotchController { state, toggle, pin, capture in
                        AnyView(NotchHUDView(model: model, usage: usage, agents: agents, linked: linked, state: state, toggle: toggle, pin: pin, capture: capture))
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
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in if fixtureRoot == nil { usage.start() } }
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
