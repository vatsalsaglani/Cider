import SwiftUI
import CiderDomain
import CiderPlatform
import CiderUI

struct NotchHUDView: View {
    @Bindable var model: AppModel
    @Bindable var usage: UsageModel
    @Bindable var agents: AgentTrackingModel
    @Bindable var linked: LinkedWorkCoordinator
    var state: NotchPresentation
    @AppStorage("notchTab") private var tab: NotchTab = .todo
    let toggle: () -> Void
    let pin: () -> Void
    let capture: () -> Void
    @State private var player = NowPlaying()
    private var tasks: [TaskItem] { model.tasks(on: LocalDay(model.notchDate)).filter { !$0.completed } }
    var body: some View {
        VStack(spacing: 0) {
            if !state.expanded && state.peekTitle == nil && (state.edge == .left || state.edge == .right) {
                Button { if state.peekTitle != nil { state.activatePeek?() } else { toggle() } } label: {
                    VStack(spacing: 14) { AppMark(); Text("\(tasks.count)"); Image(systemName: "chevron.left.forwardslash.chevron.right") }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.buttonStyle(.plain).help("Open Cider")
            } else {
                Button { if state.peekTitle != nil { state.activatePeek?() } else { toggle() } } label: {
                    HStack {
                        HStack(spacing: 4) {
                            AppMark()
                            if player.playing { Image(systemName: "waveform").font(.system(size: 10)).foregroundStyle(CiderColor.accent) }
                        }.frame(maxWidth: .infinity)
                        if state.cameraWidth > 0 { Color.clear.frame(width: state.cameraWidth) }
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                Text(countText(agents.active.filter { $0.parent == nil }.count))
                            }.foregroundStyle(agents.attentionCount > 0 ? CiderColor.accent : CiderColor.textPrimary)
                                .help("Tracked agents; \(agents.attentionCount) requesting attention")
                            HStack(spacing: 3) { Image(systemName: "checklist"); Text(countText(tasks.count)) }.help("Remaining tasks")
                        }.font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .frame(maxWidth: .infinity).padding(.trailing, 10).clipped()
                    }.frame(height: state.headerHeight)
                }.buttonStyle(.plain).help(state.expanded ? "Collapse notch" : "Open notch")
                if let title = state.peekTitle, !state.expanded {
                    Button { state.activatePeek?() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.headline)
                        Text(ResponsePreview.render(state.peekMessage)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 26).frame(height: 82).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Return to source app")
                }
                if state.expanded {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            NotchTabs(selection: $tab)
                                .onChange(of: tab) { _, _ in state.dismissCapture?() }
                            IconAction("Pin notch", symbol: state.pinned ? "pin.fill" : "pin", action: pin)
                        }
                        Group {
                            switch tab {
                            case .agents: AgentsView(model: agents, compact: true)
                            case .todo: todo
                            case .player: NotchPlayerView(player: player)
                            case .usage: NotchUsageView(model: usage)
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        HStack { Text(tab == .todo ? "\(tasks.count) remaining" : tab.rawValue).font(.caption).foregroundStyle(.secondary); Spacer(); IconAction("Open Cider", symbol: "arrow.up.forward.app") { if tab == .agents { agents.openWorkspace?() } else { model.openWorkspace?() } } }
                            .frame(height: 32)
                    }.padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 18)
                }
            }
        }
        .foregroundStyle(CiderColor.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { player.start() }.onDisappear { player.stop() }
        .background(NotchShape(edge: state.edge).fill(.black))
        .overlay {
            if state.expanded || state.peekTitle != nil {
                NotchShape(edge: state.edge).stroke(LinearGradient(colors: [.orange.opacity(0.15), .orange, .pink.opacity(0.65), .orange.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: state.peekTitle == nil ? 1 : 2).allowsHitTesting(false)
            }
        }
    }
    private func countText(_ count: Int) -> String { count > 99 ? "99+" : String(count) }
    private var todo: some View {
        VStack(alignment: .leading, spacing: 10) {
            DateNavigator(date: $model.notchDate)
            if tasks.isEmpty {
                Text("A little room to breathe.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(tasks.prefix(3)) { task in
                    LinkedNotchTaskRow(task: task, app: model, linked: linked)

                }
                Spacer(minLength: 0)
            }
            Button(action: capture) {
                HStack { Image(systemName: "plus"); Text("Add a task…"); Spacer(); Image(systemName: "return") }
                    .foregroundStyle(.secondary).padding(14).frame(height: 54)
                    .background(CiderColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).opacity(state.capturing ? 0 : 1).disabled(!model.ready)
        }
    }

}

private struct LinkedNotchTaskRow: View {
    let task: TaskItem
    let app: AppModel
    let linked: LinkedWorkCoordinator
    @State private var detail: TaskDetail?
    var body: some View {
        HStack(spacing: 8) {
            Button { Task { await app.toggle(task) } } label: { Image(systemName: "circle") }
                .help("Complete TODO").accessibilityLabel("Complete " + task.title)
            Button { linked.selectedTask = task.id; app.openWorkspace?() } label: {
                Text(task.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }.help("Open TODO details")
            if let detail, !detail.chats.isEmpty {
                Menu {
                    ForEach(Array(detail.chats.enumerated()), id: \.offset) { _, chat in
                        Button(chat.title ?? chat.identity.sessionID) { linked.route(.chat(chat.identity)) }
                    }
                } label: {
                    Label(String(detail.chats.count), systemImage: "link")
                        .font(.caption).foregroundStyle(detail.chats.contains { $0.attention != nil } ? CiderColor.accent : Color.secondary)
                }.help("Linked contributors")
            }
        }.buttonStyle(.plain).frame(minHeight: 28).disabled(app.saving)
        .task(id: linked.revision) { detail = try? await linked.model?.repository.detail(task.id) }
    }
}

struct NotchCaptureView: View {
    @Bindable var model: AppModel
    let dismiss: () -> Void
    var body: some View {
        TaskComposer(text: $model.notchDraft, autofocus: true) {
            Task { if await model.createTask(model.notchDraft, day: LocalDay(model.notchDate)) { model.notchDraft = ""; dismiss() } }
        }.disabled(model.saving).onExitCommand(perform: dismiss)
    }
}

struct NotchShape: Shape { var edge: NotchEdge; func path(in rect: CGRect) -> Path { Path(NotchOutline.path(in: rect, edge: edge)) } }
