import SwiftUI
import AppKit
import CiderDomain
import CiderUI
import CiderPlatform

private enum AgentsTab: String, CaseIterable {
    case activity = "Activity", agents = "Agents"
}

struct AgentsView: View {
    @Bindable var model: AgentTrackingModel
    var compact = false
    var viewConnections: ((TrackedSession) -> Void)?
    var connectTask: ((TrackedSession, Bool) -> Void)?
    @State private var providerFilter = "All agents"
    @State private var projectFilter = ""
    @State private var showEnded = false
    // An explicit choice stays put as connections/activity change. A new visit uses the default.
    @State private var selectedTab: AgentsTab?
    private var tab: Binding<AgentsTab> {
        Binding(get: { selectedTab ?? (model.hasConnectedAgents ? .activity : .agents) },
                set: { selectedTab = $0 })
    }
    private var visible: [TrackedSession] { model.sessions.filter { (showEnded || $0.execution != .ended) && (providerFilter == "All agents" || $0.provider.title == providerFilter) && (projectFilter.isEmpty || $0.project.localizedCaseInsensitiveContains(projectFilter) || $0.displayTitle.localizedCaseInsensitiveContains(projectFilter)) } }
    private var roots: [TrackedSession] { visible.filter { row in row.parent == nil || !visible.contains(where: { $0.id == row.parent }) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact {
                HStack { Text("Agents").font(.largeTitle.weight(.semibold)); Spacer(); IconAction("Refresh activity", symbol: "arrow.clockwise") { Task { await model.refresh() } }; Text("\(model.attentionCount) need attention").foregroundStyle(.secondary) }
                CiderPillPicker("Agents view", selection: tab, options: AgentsTab.allCases, title: { $0.rawValue })
                    .frame(width: 230)
            }
            if !compact && tab.wrappedValue == .agents {
                AgentConnectionsView(model: model)
            } else {
                activity
            }
        }.padding(compact ? 0 : 24)
        .sheet(item: $model.proposal) { proposal in
            VStack(alignment: .leading, spacing: 16) {
                Text(proposal.removing ? "Disconnect \(proposal.provider.title)" : "Connect \(proposal.provider.title)").font(.title2)
                Text(proposal.destination.path).font(.caption).textSelection(.enabled)
                ScrollView { Text(proposal.preview).font(.body.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Text("Cider collects session identifiers, workspace paths and activity names, plus up to 600 characters of each response or question request. Codex chat names come from its local title index. Other prompts, tool inputs and your answers are discarded. Disconnect removes Cider’s observer.").font(.caption)
                HStack { Button("Cancel") { model.proposal = nil }.keyboardShortcut(.cancelAction); Spacer(); Button(proposal.removing ? "Disconnect" : "Install observer") { model.apply() }.disabled(model.busy) }
            }.padding(24).frame(width: 550, height: 370)
        }
        .alert("Tracking", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact {
                HStack {
                    Picker("Provider", selection: $providerFilter) { Text("All agents").tag("All agents"); ForEach(TrackedProvider.allCases) { Text($0.title).tag($0.title) } }.frame(width: 190)
                    TextField("Filter chats or workspaces", text: $projectFilter)
                    Toggle("Recent ended", isOn: $showEnded).toggleStyle(.checkbox)
                }
            }
            if visible.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.title)
                    Text("Your agent activity will appear here").font(.headline)
                    Text(model.hasConnectedAgents ? "Start a session with a connected agent." : "Connect an agent to start tracking activity.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !compact && !model.hasConnectedAgents {
                        Button("Connect agents") { selectedTab = .agents }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(roots.prefix(compact ? 3 : 256))) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .top) {
                                    BrandImage(row.provider.rawValue)
                                    Text(row.displayTitle).font(.headline).lineLimit(2).help(row.displayTitle)
                                    Spacer(minLength: 6)
                                    Text(row.provider.title).font(.caption).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    if row.title != nil { Text(row.project).lineLimit(1) }
                                    if row.title == nil || visible.contains(where: { $0.id != row.id && $0.displayTitle == row.displayTitle && $0.project == row.project }) {
                                        Text(String(row.session.suffix(8))).monospaced()
                                    }
                                }.font(.caption).foregroundStyle(.secondary)
                                Text(row.activityLabel(at: model.now))
                                    .font(.callout).foregroundStyle(row.needsAttention(at: model.now) ? CiderColor.accent : Color.secondary)
                                HStack {
                                    if row.parent != nil { Text("Subagent ·").font(.caption) }
                                    Text(row.updated, style: .relative).font(.caption); Text("ago").font(.caption)
                                }.foregroundStyle(.secondary)
                                if !row.questions.isEmpty {
                                    Text(ResponsePreview.render(row.questions.map(\.text).joined(separator: "\n")))
                                        .font(.callout).foregroundStyle(.primary).lineLimit(compact ? 3 : nil)
                                } else if let message = row.history.last(where: { $0.lastMessage != nil })?.lastMessage, !message.isEmpty {
                                    Text(ResponsePreview.render(message)).font(.callout).foregroundStyle(.secondary).lineLimit(compact ? 2 : 8)
                                }
                                if !compact {
                                    let children = visible.filter { $0.parent == row.id }
                                    if !children.isEmpty {
                                        DisclosureGroup("\(children.count) subagents") {
                                            ForEach(children) { child in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack { Image(systemName: "arrow.turn.down.right"); Text(String(child.id.suffix(12))); Spacer(); Text(child.activityLabel(at: model.now)) }
                                                    if !child.questions.isEmpty { Text(ResponsePreview.render(child.questions.map(\.text).joined(separator: "\n"))) }
                                                }.font(.caption).padding(.vertical, 6)
                                            }
                                        }
                                    }
                                    DisclosureGroup("Recent activity") {
                                        ForEach(row.history.reversed()) { event in
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack { Text(event.questions == nil ? event.name + (event.tool.map { " · " + $0 } ?? "") : "Asked a question"); Spacer(); Text(event.time, style: .time) }
                                                if let questions = event.questions { Text(ResponsePreview.render(questions.map(\.text).joined(separator: "\n"))).foregroundStyle(.secondary) }
                                            }.font(.caption).padding(.vertical, 3)
                                        }
                                    }
                                    HStack {
                                        IconAction(row.history.last(where: { $0.origin != nil })?.origin.map { AgentDestination.taskURL(provider: row.provider, session: row.session, origin: $0) != nil ? "Open this Codex task" : "Return to " + $0.name } ?? "Source app unavailable", symbol: "arrow.up.forward.app") { model.openSource(row) }
                                        IconAction("Reveal workspace", symbol: "folder") { if row.directory.hasPrefix("/") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: row.directory) } }
                                        IconAction("Copy session ID", symbol: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(row.session, forType: .string) }
                                        if let connectTask {
                                            Menu {
                                                Button("Attach to TODO") { connectTask(row, false) }
                                                Button("Create TODO from chat") { connectTask(row, true) }
                                            } label: { Image(systemName: "link") }.help("Connect this chat to a TODO")
                                        }
                                        if let viewConnections { IconAction("View connections", symbol: "point.3.connected.trianglepath.dotted") { viewConnections(row) } }
                                        Text(String(row.session.prefix(12))).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                }
                            }.padding(compact ? 10 : 16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            .modifier(AgentCardAction(enabled: compact, action: { model.openSource(row) }))
                        }
                    }
                }
            }
            if !compact { Text("Activity describes what the agent reported. A finished response does not mean the work has been verified.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct AgentCardAction: ViewModifier {
    let enabled: Bool
    let action: () -> Void
    func body(content: Content) -> some View {
        if enabled {
            Button(action: action) { content.contentShape(Rectangle()) }.buttonStyle(.plain).help("Return to source app")
        } else { content }
    }
}
