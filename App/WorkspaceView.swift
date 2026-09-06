import SwiftUI
import CiderUI
import CiderDomain
import CiderPlatform

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel
    @Bindable var usage: UsageModel
    @Bindable var agents: AgentTrackingModel
    @State private var notes = NotesModel()
    @AppStorage("sidebarCollapsed") private var collapsed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = "Today"
    @State private var selectedDate = Date.now
    @State private var quickTask = false
    var body: some View {
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
            Group {
                if selection == "Today" { TodayView(model: model, selectedDate: $selectedDate) }
                else if selection == "Notes" { NotesView(notes: notes) }
                else if selection == "Agents" { AgentsView(model: agents) }
                else if selection == "Usage" { UsageView(model: usage) }
                else { NotchSettingsView(model: model) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 8)
        .ignoresSafeArea(.container, edges: .top)
        .background(WorkspaceBackdrop()).background(WindowChrome())
        .frame(minWidth: 760, minHeight: 540)
        .focusedSceneValue(\.activeNotes, selection == "Notes" ? notes : nil)
        .onAppear { agents.openWorkspace = { selection = "Agents"; openWindow(id: "workspace"); NSApplication.shared.activate(ignoringOtherApps: true) }; model.openWorkspace = { openWindow(id: "workspace"); NSApplication.shared.activate(ignoringOtherApps: true) } }
        .sheet(isPresented: $quickTask) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("A task for today").font(.title2); Spacer(); IconAction("Close", symbol: "xmark") { quickTask = false } }
                TaskComposer(text: $model.quickDraft, autofocus: true) {
                    Task { if await model.createTask(model.quickDraft, day: LocalDay()) { model.quickDraft = ""; quickTask = false } }
                }.disabled(model.saving)
            }.padding(24).frame(width: 460)
        }
        .alert("Couldn’t save", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var sidebarToggle: some View {
        IconAction(collapsed ? "Expand sidebar" : "Collapse sidebar", symbol: "sidebar.left") {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { collapsed.toggle() }
        }.keyboardShortcut("s", modifiers: [.command, .control])
    }
    @ViewBuilder private var captureActions: some View {
        IconAction("Quick note", symbol: "square.and.pencil") { selection = "Notes"; Task { await notes.create() } }
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
