import CryptoKit
import Dispatch
import Foundation
import CiderDomain

/// Root-scoped Markdown access. Synchronous coordination stays on a dedicated utility executor.
public struct LinkedNoteService: LinkedNoteAccess {
    private let storage: NoteFileStorage

    public init() { storage = NoteFileStorage() }
    init(testingReplacementFailure: Bool) { storage = NoteFileStorage(forceReplacementFailure: testingReplacementFailure) }

    public func resolve(_ note: NoteReference, root: FolderReference) async throws -> URL { try await storage.resolve(note, root: root) }
    public func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) async throws -> NoteFileSnapshot { try await storage.read(note, root: root, maxBytes: maxBytes) }
    public func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) async throws -> NoteReference { try await storage.create(root: root, relativeDirectory: relativeDirectory, title: title, markdown: markdown) }
    public func previewAppend(note: NoteReference, root: FolderReference, markdown: String) async throws -> NoteAppendProposal { try await storage.previewAppend(note: note, root: root, markdown: markdown) }
    public func applyAppend(_ proposal: NoteAppendProposal) async throws -> NoteFileSnapshot { try await storage.applyAppend(proposal) }
    public func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) async throws -> [NoteDocumentLink] {
        let snapshot = try await storage.read(note, root: root, maxBytes: maxBytes)
        guard !snapshot.truncated else { throw WorkStoreError.outputLimit }
        return try MarkdownLinkIndex.links(in: snapshot.markdown, source: note, knownNotes: knownNotes, rootID: root.id)
    }
}

private actor NoteFileStorage {
    private let queue = DispatchSerialQueue(label: "app.cider.linked-note-io", qos: .utility)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private let locator = NoteLocator()
    /// Replacements change filesystem identity. This preserves validity during this service lifetime;
    /// persistence needs the coordinator contract recorded in this plan's deviations.
    private var replacementIdentities: [UUID: Data?] = [:]
    private var forceReplacementFailure: Bool

    init(forceReplacementFailure: Bool = false) { self.forceReplacementFailure = forceReplacementFailure }

    func resolve(_ note: NoteReference, root: FolderReference) throws -> URL { try validatedURL(note, root: root) }

    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) throws -> NoteFileSnapshot {
        guard (1...WorkLimits.noteBytes).contains(maxBytes) else { throw WorkStoreError.invalidInput }
        let url = try validatedURL(note, root: root)
        let result = try boundedRead(url, maxBytes: maxBytes)
        return NoteFileSnapshot(noteID: note.id, markdown: result.markdown, sha256: result.sha256, modifiedAt: try locator.modifiedAt(url), truncated: result.truncated)
    }

    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) throws -> NoteReference {
        guard markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let directory = try locator.directory(relativeDirectory, in: root)
        let stem = try safeStem(title)
        for attempt in 1...10_000 {
            let suffix = attempt == 1 ? "" : " \(attempt)"
            let url = directory.appendingPathComponent(stem + suffix).appendingPathExtension("md")
            do {
                try exclusiveWrite(Data(markdown.utf8), to: url)
                return NoteReference(rootID: root.id, relativePath: try locator.relativePath(of: url, in: root), fileIdentity: try locator.identity(of: url), available: true, modifiedAt: try locator.modifiedAt(url))
            } catch let error as POSIXError where error.code == .EEXIST { continue }
        }
        throw WorkStoreError.busy
    }

    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) throws -> NoteAppendProposal {
        guard markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let snapshot = try read(note, root: root, maxBytes: WorkLimits.noteBytes)
        guard !snapshot.truncated, snapshot.markdown.utf8.count + markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        return NoteAppendProposal(note: note, root: root, expectedHash: snapshot.sha256, markdownToAppend: markdown, preview: snapshot.markdown + markdown)
    }

    func applyAppend(_ proposal: NoteAppendProposal) throws -> NoteFileSnapshot {
        guard proposal.markdownToAppend.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let url = try validatedURL(proposal.note, root: proposal.root)
        let current = try boundedRead(url, maxBytes: WorkLimits.noteBytes)
        guard !current.truncated, current.sha256 == proposal.expectedHash, current.markdown.utf8.count + proposal.markdownToAppend.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.fileChanged }
        let replacementIdentity = try coordinatedReplacement(proposal, at: url, with: Data((current.markdown + proposal.markdownToAppend).utf8))
        replacementIdentities[proposal.note.id] = replacementIdentity
        return try read(proposal.note, root: proposal.root, maxBytes: WorkLimits.noteBytes)
    }

    private func validatedURL(_ note: NoteReference, root: FolderReference) throws -> URL {
        try locator.resolve(note, root: root, expectedIdentity: replacementIdentities[note.id] ?? note.fileIdentity)
    }

    private func safeStem(_ title: String) throws -> String {
        let stem = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty, stem.utf8.count <= 180, !stem.contains("/"), !stem.contains("\\"), stem != ".", stem != ".." else { throw WorkStoreError.invalidInput }
        return stem.hasSuffix(".md") ? String(stem.dropLast(3)) : stem
    }

    /// Full hashes are needed for append conflicts, so files are capped before reading. No call reads past 64 KiB.
    private func boundedRead(_ url: URL, maxBytes: Int) throws -> (markdown: String, sha256: String, truncated: Bool) {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) } catch { throw WorkStoreError.unavailable }
        guard let size = attributes[.size] as? NSNumber, size.int64Value >= 0, size.int64Value <= Int64(WorkLimits.noteBytes) else { throw WorkStoreError.outputLimit }
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) } catch { throw WorkStoreError.unavailable }
        defer { try? handle.close() }
        let data: Data
        do { data = try handle.read(upToCount: WorkLimits.noteBytes) ?? Data() } catch { throw WorkStoreError.unavailable }
        let finalSize: Int64
        do { finalSize = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? -1 } catch { throw WorkStoreError.unavailable }
        guard finalSize >= 0, finalSize <= Int64(WorkLimits.noteBytes) else { throw WorkStoreError.outputLimit }
        guard Int64(data.count) == finalSize else { throw WorkStoreError.fileChanged }
        guard let complete = String(data: data, encoding: .utf8) else { throw WorkStoreError.invalidInput }
        var prefix = Data(data.prefix(maxBytes))
        if data.count > maxBytes {
            while !prefix.isEmpty && String(data: prefix, encoding: .utf8) == nil { prefix.removeLast() }
        }
        guard let markdown = String(data: prefix, encoding: .utf8) else { throw WorkStoreError.invalidInput }
        return (markdown, SHA256.hash(data: Data(complete.utf8)).hexadecimal, data.count > maxBytes)
    }

    private func exclusiveWrite(_ data: Data, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { if errno == EEXIST { throw POSIXError(.EEXIST) }; throw WorkStoreError.unavailable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do { try handle.write(contentsOf: data); try handle.synchronize() } catch { throw WorkStoreError.unavailable }
    }

    private func coordinatedReplacement(_ proposal: NoteAppendProposal, at url: URL, with data: Data) throws -> Data? {
        var coordinationError: NSError?
        var operationError: Error?
        var replacementIdentity: Data?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            var temporary: URL?
            defer { if let temporary { try? FileManager.default.removeItem(at: temporary) } }
            do {
                let revalidated = try self.validatedURL(proposal.note, root: proposal.root)
                guard revalidated.resolvingSymlinksInPath() == coordinatedURL.resolvingSymlinksInPath() else { throw WorkStoreError.outsideRoot }
                let current = try self.boundedRead(revalidated, maxBytes: WorkLimits.noteBytes)
                guard !current.truncated, current.sha256 == proposal.expectedHash else { throw WorkStoreError.fileChanged }
                let candidate = revalidated.deletingLastPathComponent().appendingPathComponent(".cider-append-\(UUID().uuidString)")
                temporary = candidate
                try self.exclusiveWrite(data, to: candidate)
                if self.forceReplacementFailure { throw WorkStoreError.unavailable }
                _ = try FileManager.default.replaceItemAt(revalidated, withItemAt: candidate)
                temporary = nil
                replacementIdentity = try self.locator.identity(of: try self.locator.path(proposal.note, root: proposal.root))
            } catch { operationError = error }
        }
        if let operationError { throw (operationError as? WorkStoreError) ?? WorkStoreError.unavailable }
        if coordinationError != nil { throw WorkStoreError.unavailable }
        return replacementIdentity
    }
}

private extension SHA256Digest {
    var hexadecimal: String { map { String(format: "%02x", $0) }.joined() }
}
