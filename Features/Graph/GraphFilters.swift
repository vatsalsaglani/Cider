import SwiftUI
import CiderDomain
import CiderUI

enum GraphMode: String, CaseIterable { case local = "Local", workspace = "Workspace" }

struct GraphFilterState: Hashable {
    var mode: GraphMode
    var workspaceRootID: UUID?
    var depth = 1
    var includeDone = false
    var includeIsolated = false
    var activeChatsOnly = false
    var search = ""
    var kinds = Set<LinkedEntityKind>()
    var statuses = Set<WorkTaskStatus>()
    var providers = Set<TrackedProvider>()

    func query(focus: LinkedEntityID?) -> GraphQuery {
        let scope: GraphScope = mode == .local && focus != nil
            ? .local(entity: focus!, depth: depth) : .workspace(rootID: workspaceRootID)
        return GraphQuery(scope: scope, includeDone: includeDone, includeIsolated: includeIsolated,
                          nodeKinds: kinds.sorted { $0.rawValue < $1.rawValue },
                          statuses: statuses.sorted { $0.rawValue < $1.rawValue }, activeChatsOnly: activeChatsOnly,
                          providers: providers.sorted { $0.rawValue < $1.rawValue }, search: search,
                          nodeLimit: 1_000, edgeLimit: 3_000)
    }
}

struct GraphFilters: View {
    @Binding var filters: GraphFilterState
    let focusAvailable: Bool
    let folders: [FolderReference]

    var body: some View {
        HStack(spacing: 10) {
            CiderPillPicker(
                "Graph scope",
                selection: $filters.mode,
                options: focusAvailable ? GraphMode.allCases : [.workspace],
                compact: true,
                title: \.rawValue
            ).frame(width: 170)
            if filters.mode == .local {
                Picker("Connection depth", selection: $filters.depth) { Text("One hop").tag(1); Text("Two hops").tag(2) }
                    .frame(width: 130)
            } else {
                Picker("Workspace folder", selection: $filters.workspaceRootID) {
                    Text("All workspaces").tag(UUID?.none)
                    ForEach(folders) { Text($0.path).tag(Optional($0.id)) }
                }.frame(width: 180)
            }
            Toggle("Done", isOn: $filters.includeDone).help("Include completed TODOs")
            Toggle("Isolated", isOn: $filters.includeIsolated).help("Include saved entities with no displayed edge")
            Toggle("Active chats", isOn: $filters.activeChatsOnly)
            Menu("Filters") {
                Section("Node types") { ForEach(LinkedEntityKind.allCases, id: \.self) { kind in Toggle(kind.rawValue.capitalized, isOn: binding(for: kind)) } }
                Section("TODO status") { ForEach(WorkTaskStatus.allCases, id: \.self) { status in Toggle(status.rawValue, isOn: statusBinding(for: status)) } }
                Section("Provider") { ForEach(TrackedProvider.allCases, id: \.self) { provider in Toggle(provider.title, isOn: providerBinding(for: provider)) } }
            }
        }
        .onChange(of: focusAvailable) { _, available in
            if !available { filters.mode = .workspace }
        }
    }

    private func binding(for kind: LinkedEntityKind) -> Binding<Bool> { Binding { filters.kinds.contains(kind) } set: { enabled in if enabled { filters.kinds.insert(kind) } else { filters.kinds.remove(kind) } } }
    private func statusBinding(for status: WorkTaskStatus) -> Binding<Bool> { Binding { filters.statuses.contains(status) } set: { enabled in if enabled { filters.statuses.insert(status) } else { filters.statuses.remove(status) } } }
    private func providerBinding(for provider: TrackedProvider) -> Binding<Bool> { Binding { filters.providers.contains(provider) } set: { enabled in if enabled { filters.providers.insert(provider) } else { filters.providers.remove(provider) } } }
}
