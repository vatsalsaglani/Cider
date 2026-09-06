import SwiftUI
import CiderUI
import CiderDomain
import CiderPlatform

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel
    @Bindable var usage: UsageModel
    @Bindable var agents: AgentTrackingModel
    @Bindable var linked: LinkedWorkCoordinator
    private var notes: NotesModel { linked.notes }
    @AppStorage("sidebarCollapsed") private var collapsed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = "Today"
    @State private var selectedDate = Date.now
    @State private var quickTask = false
    var body: some View {
        workspaceLayout
        .overlay(alignment: .bottomTrailing) {
            if ProcessInfo.processInfo.environment["CIDER_LINKED_FIXTURE_ROOT"] != nil {
                Text("Fixture workspace · sample data").font(.caption).padding(8)
                    .background(.black.opacity(0.85), in: Capsule()).padding(12).allowsHitTesting(false)
            }
        }
        .focusedSceneValue(\.activeNotes, selection == "Notes" ? notes : nil)
        .onAppear { agents.openWorkspace = { selection = "Agents"; openWindow(id: "workspace"); NSApplication.shared.activate(ignoringOtherApps: true) }; model.openWorkspace = { openWindow(id: "workspace"); NSApplication.shared.activate(ignoringOtherApps: true) } }
        .onAppear { linked.showNotes = { selection = "Notes" } }
        .onChange(of: linked.model?.selectedDetail?.revision) { _, _ in Task<Void, Never> { await linked.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task<Void, Never> { await model.refresh() } }
        .sheet(isPresented: Binding(get: { linked.selectedTask != nil }, set: { if !$0 { linked.selectedTask = nil } }), onDismiss: { Task<Void, Never> { await model.refresh() } }) {
            if let id = linked.selectedTask, let work = linked.model {
                TaskDetailView(taskID: id, model: work, navigate: linked.route)
                    .frame(width: 720, height: 620)
                    .sheet(isPresented: Binding(get: { linked.attachmentTask != nil }, set: { if !$0 { linked.attachmentTask = nil } })) {
                        if let taskID = linked.attachmentTask {
                            NoteAttachmentPicker(model: work, taskID: taskID, onComplete: { linked.attachmentTask = nil; Task<Void, Never> { await work.loadDetail(id) } })
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(get: { linked.connectionNote != nil }, set: { if !$0 { linked.connectionNote = nil } }), onDismiss: linked.resumeNavigation) {
            if let id = linked.connectionNote, let work = linked.model {
                NoteConnectionsView(noteID: id, model: work, navigate: linked.route).frame(width: 600, height: 500)
            }
        }
        .alert("Linked work", isPresented: Binding(get: { linked.error != nil }, set: { if !$0 { linked.error = nil } })) {
            Button("OK") { linked.error = nil }
        } message: { Text(linked.error ?? "") }
        .sheet(isPresented: Binding(get: { linked.checkpointProposal != nil }, set: { _ in })) {
            if let entry = linked.checkpointEntry, let proposal = linked.checkpointProposal {
                VStack(spacing: 0) {
                    CheckpointNotePreview(entry: entry, proposal: proposal, destination: proposal.note.relativePath,
                        onConfirm: { _ in Task<Void, Never> { await linked.confirmCheckpoint() } },
                        onCancel: linked.cancelCheckpoint).disabled(linked.appending)
                    linkedError
                }
            }
        }
        .sheet(isPresented: $linked.linking, onDismiss: linked.resumeNavigation) { linkingSheet }
        .sheet(isPresented: $linked.createDraft, onDismiss: { linked.resumeNavigation(); Task<Void, Never> { await model.refresh() } }) { draftSheet }
        .sheet(isPresented: $quickTask) { quickTaskSheet }
        .alert("Couldn’t save", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var workspaceLayout: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 14) {
                if collapsed { sidebarToggle }
                HStack { AppMark().frame(width: 36); if !collapsed { Text("Cider"); Spacer(); sidebarToggle } }.font(.title2.weight(.semibold)).padding(.vertical, 12)
                navigation("Today", symbol: "checklist")
                if selection == "Today" && !collapsed { DateNavigator(date: $selectedDate) }
                navigation("Notes", symbol: "doc.text")
                navigation("Agents", symbol: "point.3.connected.trianglepath.dotted")
                navigation("Usage", symbol: "chart.pie")
                Spacer()
                Group {
                    if collapsed { VStack(spacing: 10) { captureActions } }
                    else { HStack { captureActions; Spacer() } }
                }
                navigation("Settings", symbol: "gearshape")
            }.padding(.vertical, 16).padding(.horizontal, 10).frame(width: collapsed ? 64 : 225).frame(maxHeight: .infinity)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.06)))
                .padding(.top, 26)
            workspaceContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 8)
        .ignoresSafeArea(.container, edges: .top)
        .background(WorkspaceBackdrop()).background(WindowChrome())
        .frame(minWidth: 760, minHeight: 540)
    }
    @ViewBuilder private var linkedError: some View {
        if let message = linked.error {
            Text(message).font(.callout).foregroundStyle(CiderColor.accent)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16).padding(.bottom, 8)
        }
    }
    private var linkingSheet: some View {

            VStack(alignment: .leading, spacing: 14) {
                Text("Attach to TODO").font(.title2)
                linkedError
                ScrollView {
                    ForEach(model.workTasks) { task in
                        Button(task.title) { attachTask(task.id) }
                    }
                }
                Button("Cancel") { linked.linking = false }
            }.padding(24).frame(width: 480, height: 400).disabled(linked.linkingBusy)
            }
    private var draftSheet: some View {

            VStack(alignment: .leading, spacing: 14) {
                Text("Create linked TODO").font(.title2)
                linkedError
                TextField("Title", text: $linked.draftTitle)
                TextEditor(text: $linked.draftDescription).frame(height: 160)
                Text("The chat contributes to this TODO. Its responses never mark it done.").font(.caption)
                HStack {
                    Button("Cancel") { linked.createDraft = false }
                    Spacer()
                    Button("Create TODO") { Task<Void, Never> { await linked.createAndAttach() } }
                        .disabled(linked.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24).frame(width: 480).disabled(linked.linkingBusy)
            }
    private var quickTaskSheet: some View {

            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("A task for today").font(.title2); Spacer(); IconAction("Close", symbol: "xmark") { quickTask = false } }
                TaskComposer(text: $model.quickDraft, autofocus: true) {
                    Task<Void, Never> { if await model.createTask(model.quickDraft, day: LocalDay()) { model.quickDraft = ""; quickTask = false } }
                }.disabled(model.saving)
            }.padding(24).frame(width: 460)
            }
    private func attachTask(_ id: UUID) {
        Task<Void, Never> { _ = await linked.attach(to: id) }
    }
    @ViewBuilder private var workspaceContent: some View {
                if selection == "Today" { TodayView(model: model, openTask: { linked.selectedTask = $0 }, selectedDate: $selectedDate) }
                else if selection == "Notes" { NotesView(notes: notes, showConnections: { Task<Void, Never> { await linked.showConnections() } }) }
                else if selection == "Agents" { AgentsView(model: agents, connectTask: { row, create in
                    guard let chat = linked.reference(row) else { return }
                    linked.route(create ? .createTaskFromChat(chat) : .attachChat(chat))
                }) }
                else if selection == "Usage" { UsageView(model: usage) }
                else { NotchSettingsView(model: model) }
    }
    private var sidebarToggle: some View {
        IconAction(collapsed ? "Expand sidebar" : "Collapse sidebar", symbol: "sidebar.left") {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { collapsed.toggle() }
        }.keyboardShortcut("s", modifiers: [.command, .control])
    }
    @ViewBuilder private var captureActions: some View {
        IconAction("Quick note", symbol: "square.and.pencil") { selection = "Notes"; Task<Void, Never> { await notes.create() } }
        IconAction("Quick task", symbol: "text.badge.plus", primary: true) { quickTask = true }.disabled(!model.ready)
    }
    private func navigation(_ title: String, symbol: String) -> some View {
        Button { selection = title } label: {
            HStack { Image(systemName: symbol).frame(width: 18); if !collapsed { Text(title); Spacer() } }
                .frame(width: collapsed ? 44 : nil, height: 40).frame(maxWidth: collapsed ? nil : .infinity, alignment: .leading).padding(.horizontal, collapsed ? 0 : 10)
                .background(selection == title ? Color.white.opacity(0.085) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }

}
