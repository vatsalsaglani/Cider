import SwiftUI
import CiderDomain
import CiderUI

struct WorkGraphView: LinkedGraphFeature {
    let model: LinkedWorkModel
    let focus: LinkedEntityID?
    var revision: Int64 = 0
    let navigate: (LinkedRoute) -> Void
    @State private var filters: GraphFilterState
    @State private var folders: [FolderReference] = []
    @State private var snapshot: GraphSnapshot?
    @State private var viewport = GraphViewport()
    @State private var loading = false
    @State private var failure: String?
    @State private var generation = 0
    @State private var layoutTask: Task<Void, Never>?
    @State private var canvasSize = CGSize(width: 420, height: 360)
    @State private var showInspector = true
    @State private var fitted = false

    init(model: LinkedWorkModel, focus: LinkedEntityID?, navigate: @escaping (LinkedRoute) -> Void) {
        self.init(model: model, focus: focus, revision: 0, navigate: navigate)
    }
    init(model: LinkedWorkModel, focus: LinkedEntityID?, revision: Int64, navigate: @escaping (LinkedRoute) -> Void) {
        self.model = model; self.focus = focus; self.revision = revision; self.navigate = navigate
        _filters = State(initialValue: GraphFilterState(mode: focus == nil ? .workspace : .local))
        _viewport = State(initialValue: GraphViewport(selected: focus))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(filters.mode == .local ? "Local connections" : "Graph").font(.largeTitle.weight(.semibold))
                    Text("Your notes, tasks and agent conversations, connected.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                IconAction("Zoom out", symbol: "minus.magnifyingglass") { viewport.zoom(by: 0.8) }
                IconAction("Zoom in", symbol: "plus.magnifyingglass") { viewport.zoom(by: 1.25) }
                IconAction("Fit graph to visible nodes", symbol: "arrow.down.right.and.arrow.up.left") { fit() }
                IconAction("Reset graph layout", symbol: "arrow.counterclockwise") { viewport.resetLayout(); fitted = false; reload() }
                IconAction("Toggle connection list", symbol: "sidebar.right") { showInspector.toggle() }
            }
            GraphFilters(filters: $filters, focusAvailable: focus != nil, folders: folders)
            TextField("Search saved TODOs, chats and notes", text: $filters.search).textFieldStyle(.roundedBorder)
            if loading { ProgressView("Loading connections…").controlSize(.small) }
            if let failure { ContentUnavailableView("Graph unavailable", systemImage: "exclamationmark.triangle", description: Text(failure)) }
            else if let snapshot, !snapshot.nodes.isEmpty {
                if snapshot.truncated { Label("Showing bounded results. Narrow filters to explore more connections.", systemImage: "line.3.horizontal.decrease.circle").font(.caption).foregroundStyle(CiderColor.warning) }
                HSplitView {
                    GraphCanvas(snapshot: snapshot, viewport: $viewport, onSizeChanged: { canvasSize = $0 }, open: open).frame(minWidth: 280, minHeight: 300)
                    if showInspector {
                        GraphInspector(snapshot: snapshot, viewport: $viewport, model: model, navigate: navigate, reload: reload, workspace: workspaceLabel).frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
                    }
                }
                HStack(spacing: 16) {
                    Label("\(snapshot.nodes.filter { $0.id.kind == .note }.count) notes", systemImage: "doc.text")
                    Label("\(snapshot.nodes.filter { $0.id.kind == .task }.count) tasks", systemImage: "checklist")
                    Label("\(snapshot.nodes.filter { $0.id.kind == .chat }.count) chats", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    Text("\(snapshot.edges.count) connections")
                }.font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    if !loading {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 32)).foregroundStyle(CiderColor.accent.opacity(0.7))
                        Text("Your connections start here").font(.title2.weight(.semibold))
                        Text("Notes and tasks appear here as you create them.\nConnect notes with [[Note name]] to draw a link.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if !filters.search.isEmpty || !filters.includeIsolated || !filters.kinds.isEmpty || !filters.providers.isEmpty {
                            Button("Clear filters") { filters = GraphFilterState(mode: .workspace) }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CiderColor.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: GraphRequest(filters: filters, focus: focus)) { await reloadAsync() }
        .onChange(of: revision) { _, _ in reload() }
        .onChange(of: focus) { _, newFocus in
            viewport.select(newFocus); fitted = false
            if newFocus != nil { filters.mode = .local }
        }
        .onDisappear { generation += 1; layoutTask?.cancel(); layoutTask = nil; viewport.hide() }
    }

    private func loadFolders() async { folders = (try? await model.repository.folders()) ?? [] }
    private func reload() { Task { await reloadAsync() } }
    private func reloadAsync() async {
        generation += 1; let request = generation; layoutTask?.cancel(); layoutTask = nil; viewport.setLayoutActive(true)
        loading = true; failure = nil
        do {
            await loadFolders()
            let result = try await model.repository.graph(filters.query(focus: focus))
            guard request == generation, !Task.isCancelled else { return }
            snapshot = result; loading = false
            let preserved = viewport.positions
            layoutTask = Task { [result, preserved] in
                do {
                    let layout = try await GraphLayout.compute(snapshot: result, preserving: preserved)
                    guard request == generation, !Task.isCancelled else { return }
                    viewport.apply(layout)
                    if !fitted, !layout.positions.isEmpty { fit(); fitted = true }
                } catch is CancellationError { }
                catch { guard request == generation else { return }; failure = "The graph layout could not be completed."; viewport.hide() }
            }
        } catch is CancellationError { guard request == generation else { return }; loading = false; viewport.hide() }
        catch { guard request == generation else { return }; loading = false; viewport.hide(); failure = "Saved relationships could not be loaded. Try again." }
    }
    private func open(_ id: LinkedEntityID) {
        switch id { case .task(let id): navigate(.task(id)); case .note(let id): navigate(.note(id)); case .chat(let id): navigate(.chat(id)) }
    }
    private func fit() {
        guard let snapshot else { return }
        let visible = Set(snapshot.nodes.map(\.id))
        viewport.fit(
            to: GraphLayoutResult(positions: viewport.positions.filter { visible.contains($0.key) }),
            canvasWidth: canvasSize.width,
            canvasHeight: canvasSize.height,
            padding: 56
        )
    }
    private var workspaceLabel: String {
        if filters.mode == .local { return "Focused local graph" }
        guard let rootID = filters.workspaceRootID else { return "All workspaces" }
        return folders.first(where: { $0.id == rootID })?.path ?? "Unavailable workspace"
    }
}

private struct GraphRequest: Hashable {
    let filters: GraphFilterState
    let focus: LinkedEntityID?
}
