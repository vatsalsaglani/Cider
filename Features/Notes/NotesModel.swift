import AppKit
import Observation
import Foundation
import CiderDomain
import CiderData

@MainActor @Observable
final class NotesModel {
    @ObservationIgnored var onRename: ((URL, String) async -> Void)?
    @ObservationIgnored var onCreateTask: ((URL) async -> Void)?
    @ObservationIgnored var onConnections: ((URL) async -> Void)?
    @ObservationIgnored var onScan: (([URL]) async -> Void)?
    @ObservationIgnored var onFileOpened: ((URL) async -> Void)?
    @ObservationIgnored var onFileSaved: ((URL) async -> Void)?
    var folders: [URL] = []
    var files: [URL] = []
    var trees: [WorkspaceNode] = []
    var expandedFolders: Set<String> = [] {
        didSet { defaults.set(Array(expandedFolders).sorted(), forKey: "expandedNoteFolders") }
    }
    var tabs: [URL] = [] {
        didSet { defaults.set(tabs.map(\.path), forKey: "openNoteTabs") }
    }
    var fragment = ""
    var opening = false
    var selectedFolder: URL?
    var selected: URL? {
        didSet { defaults.set(selected?.path, forKey: "selectedNoteTab") }
    }
    var body = ""
    var header = ""
    var status = ""
    var error: String?
    var generation = UUID()
    private var saving = false
    private var original = ""
    private var saveTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let defaultFolder: URL
    private var creating = false
    init(folders: [URL]? = nil, defaults: UserDefaults = .standard, defaultFolder: URL = DefaultNotesFolder.url) {
        self.defaults = defaults; self.defaultFolder = defaultFolder
        self.folders = folders ?? (defaults.stringArray(forKey: "workspaceFolders") ?? []).map { URL(fileURLWithPath: $0) }
        let roots = self.folders
        expandedFolders = Set(defaults.stringArray(forKey: "expandedNoteFolders") ?? roots.map(\.path))
        let restoredTabs = (defaults.stringArray(forKey: "openNoteTabs") ?? []).map { URL(fileURLWithPath: $0) }
            .filter { url in roots.contains { url.path.hasPrefix($0.path + "/") } && FileManager.default.fileExists(atPath: url.path) }
        tabs = restoredTabs
        let savedSelection = defaults.string(forKey: "selectedNoteTab").map { URL(fileURLWithPath: $0) }
        let restore = savedSelection.flatMap { restoredTabs.contains($0) ? $0 : nil } ?? restoredTabs.last
        scan()
        if let restore { Task { [weak self] in
            guard let self, self.selected == nil, !self.opening else { return }
            await self.open(restore)
        } }
    }
    func addFolder() {
        let picker = NSOpenPanel(); picker.canChooseDirectories = true; picker.canChooseFiles = false; picker.allowsMultipleSelection = true
        guard picker.runModal() == .OK else { return }
        for url in picker.urls where !folders.contains(url) { folders.append(url) }
        defaults.set(folders.map(\.path), forKey: "workspaceFolders"); scan()
    }
    func ciderFolderForCLI() async throws -> URL {
        let root = try await DefaultNotesFolder.prepare(at: defaultFolder)
        if !folders.contains(root) {
            folders.append(root)
            defaults.set(folders.map(\.path), forKey: "workspaceFolders")
        }
        return root
    }
    func allowsCLIWrite(at url: URL) -> Bool {
        if defaults.string(forKey: "noteDraft:" + url.path) != nil { return false }
        guard selected?.standardizedFileURL == url.standardizedFileURL else { return true }
        return !opening && !saving && header + body == original
    }
    func receivedCLIWrite(at url: URL, markdown: String) {
        guard selected?.standardizedFileURL == url.standardizedFileURL else { return }
        guard !saving, header + body == original else { status = "Changed on disk · your draft is kept"; return }
        let parts = MarkdownParts(markdown)
        original = markdown; header = parts.header; body = parts.body; status = "Saved"; generation = UUID()
    }
    var renameTarget: URL?
    var renameDraft = ""
    func requestRename(_ url: URL) {
        renameDraft = url.lastPathComponent
        renameTarget = url
    }
    func confirmRename() {
        guard let url = renameTarget else { return }
        let name = renameDraft
        renameTarget = nil
        Task { await onRename?(url, name) }
    }
    func didRename(_ old: URL, to new: URL) {
        tabs = tabs.map { $0 == old ? new : $0 }
        if selected == old { selected = new; selectedFolder = new.deletingLastPathComponent(); generation = UUID() }
        scan()
    }
    func removeFolder(_ url: URL) async {
        guard await save() else { return }
        folders.removeAll { $0 == url }
        tabs.removeAll { $0.path.hasPrefix(url.path + "/") }
        if selected?.path.hasPrefix(url.path + "/") == true {
            selected = nil; body = ""; header = ""; original = ""
        }
        if selectedFolder?.path.hasPrefix(url.path) == true { selectedFolder = nil }
        defaults.set(folders.map(\.path), forKey: "workspaceFolders")
        scan()
    }
    func scan() {
        let roots = folders
        Task {
            let scanned = await Task.detached(priority: .utility) {
                var result: [URL] = []
                for root in roots {
                    guard result.count < 2000 else { break }
                    guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
                    while let url = e.nextObject() as? URL {
                        if ["node_modules", ".git"].contains(url.lastPathComponent) { e.skipDescendants(); continue }
                        if ["md", "markdown"].contains(url.pathExtension.lowercased()) { result.append(url) }
                        if result.count >= 2000 { break }
                    }
                }
                return result.sorted { $0.path < $1.path }
            }.value
            guard roots == folders else { return }
            files = scanned
            trees = roots.map { WorkspaceNode.tree(root: $0, files: files) }
            await onScan?(files)
        }
    }
    func close(_ url: URL) async {
        if url == selected {
            guard await save() else { return }
            let remaining = tabs.filter { $0 != url }
            if let next = remaining.last { await open(next); guard selected == next else { return } }
            else { selected = nil; body = ""; header = ""; original = "" }
        }
        tabs.removeAll { $0 == url }
    }
    func openLink(_ href: String) {
        guard let current = selected else { return }
        guard let url = URL(string: href, relativeTo: current)?.absoluteURL else { return }
        if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url); return }
        guard url.isFileURL else { error = "This link type isn’t supported."; return }
        let anchor = url.fragment?.removingPercentEncoding ?? ""
        let target = URL(fileURLWithPath: url.path)
        guard ["md", "markdown"].contains(target.pathExtension.lowercased()) else { error = "This link doesn’t point to a Markdown note."; return }
        Task { await open(target, anchor: anchor) }
    }
    func open(_ url: URL, anchor: String = "") async {
        guard !opening else { return }
        opening = true; defer { opening = false }
        saveTask?.cancel()
        while saving { try? await Task.sleep(for: .milliseconds(20)) }
        guard folders.contains(where: { url.resolvingSymlinksInPath().path.hasPrefix($0.resolvingSymlinksInPath().path + "/") }) else { error = "This note points outside the selected folders."; return }
        guard await save() else { return }
        do {
            let text = try await Task.detached { let bytes = try Data(contentsOf: url); guard bytes.count < 2_000_000, let text = String(data: bytes, encoding: .utf8) else { throw CocoaError(.fileReadTooLarge) }; return text }.value
            guard header + body == original else { error = "Your note changed while opening another file. Please try again."; return }
            if !tabs.contains(url) { tabs.append(url) }
            fragment = anchor
            var folder = url.deletingLastPathComponent()
            while folders.contains(where: { folder.path == $0.path || folder.path.hasPrefix($0.path + "/") }) {
                expandedFolders.insert(folder.path); folder.deleteLastPathComponent()
            }
            selectedFolder = url.deletingLastPathComponent()
            selected = url; original = text; header = ""; body = text
            let parts = MarkdownParts(text); header = parts.header; body = parts.body
            if let draft = defaults.string(forKey: "noteDraft:" + url.path), draft != text { let parts = MarkdownParts(draft); header = parts.header; body = parts.body; status = "Recovered draft" } else { status = "Saved" }
            generation = UUID()
            await onFileOpened?(url)
        } catch { self.error = "This note could not be opened." }
    }
    func create(in destination: URL? = nil) async {
        guard !creating, !opening else { return }
        creating = true
        defer { creating = false }
        guard await save() else { return }
        if folders.isEmpty, destination == nil {
            do {
                let root = try await DefaultNotesFolder.prepare(at: defaultFolder)
                // Folder selection can change while disk work is suspended.
                if folders.isEmpty {
                    folders = [root]; selectedFolder = root
                    defaults.set(folders.map(\.path), forKey: "workspaceFolders")
                }
            } catch {
                self.error = "Cider’s notes folder couldn’t be created. Add a folder to choose another location."
                return
            }
        }
        guard let folder = destination ?? selectedFolder ?? selected?.deletingLastPathComponent() ?? folders.first else { return }
        guard folders.contains(where: { folder.resolvingSymlinksInPath().path == $0.resolvingSymlinksInPath().path || folder.resolvingSymlinksInPath().path.hasPrefix($0.resolvingSymlinksInPath().path + "/") }) else { error = "Choose a workspace folder first."; return }
        do {
            let url = try await DefaultNotesFolder.createNote(in: folder)
            scan(); await open(url)
        } catch { self.error = "Couldn’t create this note." }
    }
    func selectTab(offset: Int) async {
        guard !tabs.isEmpty else { return }
        let current = selected.flatMap { tabs.firstIndex(of: $0) } ?? 0
        await open(tabs[(current + offset + tabs.count) % tabs.count])
    }
    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func copyPath(_ url: URL) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string) }
    func changed(_ value: String) {
        body = value; defaults.set(header + value, forKey: "noteDraft:" + (selected?.path ?? "")); status = "Saving…"; saveTask?.cancel()
        saveTask = Task { do { try await Task.sleep(for: .milliseconds(500)) } catch { return }; _ = await save() }
    }
    func save() async -> Bool {
        guard let url = selected else { return true }
        guard !saving else { return false }
        let text = header + body, base = original
        guard text != base else { return true }
        saving = true
        defer { saving = false }
        do {
            try await Task.detached(priority: .utility) {
                var coordinationError: NSError?
                var failure: Error?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
                    do {
                        guard try String(contentsOf: target, encoding: .utf8) == base else { throw CocoaError(.fileWriteFileExists) }
                        try text.write(to: target, atomically: true, encoding: .utf8)
                    } catch { failure = error }
                }
                if let error = coordinationError ?? failure as NSError? { throw error }
            }.value
            original = text; await onFileSaved?(url); status = "Saved"; if header + body == text { defaults.removeObject(forKey: "noteDraft:" + url.path) }; if header + body != text { saveTask = Task { _ = await save() } }; return true
        } catch { status = "Unsaved"; self.error = "The file changed or couldn’t be saved. Your writing remains open; copy it before closing."; return false }
    }
    func pasteImage(_ data: Data, name: String) -> Bool {
        guard let url = selected, let image = NSImage(data: data), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]), bitmap.pixelsWide * bitmap.pixelsHigh <= 40_000_000 else { return false }
        let folder = url.deletingPathExtension().appendingPathExtension("assets")
        guard folder.resolvingSymlinksInPath().path.hasPrefix(url.deletingLastPathComponent().resolvingSymlinksInPath().path + "/") else { self.error = "The asset folder points outside this workspace."; return false }
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); try png.write(to: folder.appending(path: URL(fileURLWithPath: name).lastPathComponent), options: .atomic); return true } catch { self.error = "The image could not be saved."; return false }
    }
}
