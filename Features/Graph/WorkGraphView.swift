import SwiftUI
import CiderDomain
import CiderUI

struct WorkGraphView: LinkedGraphFeature {
    let model: LinkedWorkModel
    let focus: LinkedEntityID?
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

    init(model: LinkedWorkModel, focus: LinkedEntityID?, navigate: @escaping (LinkedRoute) -> Void) {
        self.model = model; self.focus = focus; self.navigate = navigate
        _filters = State(initialValue: GraphFilterState(mode: focus == nil ? .workspace : .local))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(filters.mode == .local ? "Local connections" : "Workspace graph").font(.title2.weight(.semibold))
                Spacer()
                IconAction("Zoom out", symbol: "minus.magnifyingglass") { viewport.zoom(by: 0.8) }
                IconAction("Zoom in", symbol: "plus.magnifyingglass") { viewport.zoom(by: 1.25) }
                IconAction("Fit graph to visible nodes", symbol: "arrow.down.right.and.arrow.up.left") { fit() }
                IconAction("Reset graph layout", symbol: "arrow.counterclockwise") { viewport.resetLayout(); reload() }
            }
            GraphFilters(filters: $filters, focusAvailable: focus != nil, folders: folders)
            TextField("Search saved TODOs, chats and notes", text: $filters.search).textFieldStyle(.roundedBorder)
            if loading { ProgressView("Loading saved relationships…").controlSize(.small) }
            if let failure { ContentUnavailableView("Graph unavailable", systemImage: "exclamationmark.triangle", description: Text(failure)) }
            else if let snapshot {
                if snapshot.truncated { Label("Showing bounded results. Narrow filters to explore more connections.", systemImage: "line.3.horizontal.decrease.circle").font(.caption).foregroundStyle(CiderColor.warning) }
                HSplitView {
                    GraphCanvas(snapshot: snapshot, viewport: $viewport, onSizeChanged: { canvasSize = $0 }).frame(minWidth: 420, minHeight: 360)
                    GraphInspector(snapshot: snapshot, viewport: $viewport, model: model, navigate: navigate, reload: reload, workspace: workspaceLabel).frame(minWidth: 290, idealWidth: 330)
                }
            } else if !loading {
                ContentUnavailableView("No saved connections", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Attach a chat or note to a TODO, or include isolated saved work."))
            }
        }
        .padding(20).background(CiderColor.background)
        .task { await loadFolders() }
        .task(id: GraphRequest(filters: filters, focus: focus)) { await reloadAsync() }
        .onChange(of: focus) { _, newFocus in if newFocus != nil { filters.mode = .local } }
        .onDisappear { generation += 1; layoutTask?.cancel(); layoutTask = nil; viewport.hide() }
    }

    private func loadFolders() async { folders = (try? await model.repository.folders()) ?? [] }
    private func reload() { Task { await reloadAsync() } }
    private func reloadAsync() async {
        generation += 1; let request = generation; layoutTask?.cancel(); layoutTask = nil; viewport.setLayoutActive(true)
        loading = true; failure = nil
        do {
            let result = try await model.repository.graph(filters.query(focus: focus))
            guard request == generation, !Task.isCancelled else { return }
            snapshot = result; loading = false
            let preserved = viewport.positions
            layoutTask = Task { [result, preserved] in
                do {
                    let layout = try await GraphLayout.compute(snapshot: result, preserving: preserved)
                    guard request == generation, !Task.isCancelled else { return }
                    viewport.apply(layout)
                } catch is CancellationError { }
                catch { guard request == generation else { return }; failure = "The graph layout could not be completed."; viewport.hide() }
            }
        } catch is CancellationError { loading = false; viewport.hide() }
        catch { guard request == generation else { return }; loading = false; viewport.hide(); failure = "Saved relationships could not be loaded. Try again." }
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
