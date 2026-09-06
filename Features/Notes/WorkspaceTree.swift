import Foundation
import SwiftUI

struct WorkspaceNode: Identifiable, Sendable {
    let url: URL
    var id: URL { url }
    let children: [WorkspaceNode]?
    static func tree(root: URL, files: [URL]) -> WorkspaceNode {
        let prefix = root.path + "/"
        let descendants = files.filter { $0.path.hasPrefix(prefix) }
        let groups = Dictionary(grouping: descendants) { String($0.path.dropFirst(prefix.count).split(separator: "/").first ?? "") }
        let children = groups.keys.sorted().map { name -> WorkspaceNode in
            let url = root.appending(path: name)
            if groups[name]?.contains(url) == true { return WorkspaceNode(url: url, children: nil) }
            return tree(root: url, files: groups[name] ?? [])
        }.sorted { ($0.children == nil ? 1 : 0, $0.url.lastPathComponent.lowercased()) < ($1.children == nil ? 1 : 0, $1.url.lastPathComponent.lowercased()) }
        return WorkspaceNode(url: root, children: children)
    }
}

struct WorkspaceTreeRow: View {
    let node: WorkspaceNode
    @Bindable var notes: NotesModel
    private var expanded: Bool { notes.expandedFolders.contains(node.url.path) }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children {
                Button {
                    notes.selectedFolder = node.url
                    if expanded { notes.expandedFolders.remove(node.url.path) }
                    else { notes.expandedFolders.insert(node.url.path) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold)).frame(width: 12)
                        Image(systemName: expanded ? "folder.fill" : "folder").foregroundStyle(.secondary)
                        Text(node.url.lastPathComponent).lineLimit(1)
                        Spacer(minLength: 0)
                    }.padding(.vertical, 7).contentShape(Rectangle())
                }.buttonStyle(.plain).help(node.url.path)
                    .accessibilityLabel(node.url.lastPathComponent)
                    .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                    .contextMenu {
                        Button("New Note Here", systemImage: "square.and.pencil") { Task { await notes.create(in: node.url) } }
                        Button("Reveal in Finder", systemImage: "folder") { notes.reveal(node.url) }
                        if notes.folders.contains(node.url) {
                            Button("Remove from workspace") { Task { await notes.removeFolder(node.url) } }
                        }
                        Button("Copy Path", systemImage: "doc.on.doc") { notes.copyPath(node.url) }
                    }
                if expanded {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(children) { WorkspaceTreeRow(node: $0, notes: notes) }
                    }
                    .padding(.leading, 18)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.10)).frame(width: 1).padding(.leading, 5)
                    }
                }
            } else {
                Button { Task { await notes.open(node.url) } } label: {
                    HStack(spacing: 6) {
                        Color.clear.frame(width: 12, height: 1)
                        Image(systemName: "doc.text").foregroundStyle(.secondary)
                        Text(node.url.lastPathComponent).lineLimit(1)
                        Spacer(minLength: 0)
                    }.padding(.vertical, 7).padding(.trailing, 4)
                        .background(notes.selected?.path == node.url.path ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).help(node.url.path).disabled(notes.opening)
                .contextMenu {
                    Button("Create TODO from note") { Task { await notes.onCreateTask?(node.url) } }
                    Button("Rename note") { notes.requestRename(node.url) }
                    Button("Connections", systemImage: "link") { Task { await notes.onConnections?(node.url) } }
                    Button("Open", systemImage: "doc.text") { Task { await notes.open(node.url) } }
                    Button("New Note in This Folder", systemImage: "square.and.pencil") { Task { await notes.create(in: node.url.deletingLastPathComponent()) } }
                    Button("Reveal in Finder", systemImage: "folder") { notes.reveal(node.url) }
                    Button("Copy Path", systemImage: "doc.on.doc") { notes.copyPath(node.url) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
