import CryptoKit
import Foundation
import CiderDomain

/// Root-scoped Markdown access. The actor keeps synchronous file work off callers' executors.
public struct LinkedNoteService: LinkedNoteAccess {
    private let storage: NoteFileStorage

    public init() { storage = NoteFileStorage() }

    public func resolve(_ note: NoteReference, root: FolderReference) async throws -> URL {
        try await storage.resolve(note, root: root)
    }

    public func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) async throws -> NoteFileSnapshot {
        try await storage.read(note, root: root, maxBytes: maxBytes)
    }

    public func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) async throws -> NoteReference {
        try await storage.create(root: root, relativeDirectory: relativeDirectory, title: title, markdown: markdown)
    }

    public func previewAppend(note: NoteReference, root: FolderReference, markdown: String) async throws -> NoteAppendProposal {
        try await storage.previewAppend(note: note, root: root, markdown: markdown)
    }

    public func applyAppend(_ proposal: NoteAppendProposal) async throws -> NoteFileSnapshot {
        try await storage.applyAppend(proposal)
    }

    public func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) async throws -> [NoteDocumentLink] {
        let snapshot = try await storage.read(note, root: root, maxBytes: maxBytes)
        guard !snapshot.truncated else { throw WorkStoreError.outputLimit }
        return try MarkdownLinkIndex.links(in: snapshot.markdown, source: note, knownNotes: knownNotes, rootID: root.id)
    }
}

private actor NoteFileStorage {
    private let locator = NoteLocator()

    func resolve(_ note: NoteReference, root: FolderReference) throws -> URL {
        try locator.resolve(note, root: root)
    }

    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) throws -> NoteFileSnapshot {
        guard (1...WorkLimits.noteBytes).contains(maxBytes) else { throw WorkStoreError.invalidInput }
        let url = try locator.resolve(note, root: root)
        let result = try boundedRead(url, maxBytes: maxBytes)
        return NoteFileSnapshot(
            noteID: note.id,
            markdown: result.markdown,
            sha256: result.sha256,
            modifiedAt: try locator.modifiedAt(url),
            truncated: result.truncated
        )
    }

    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) throws -> NoteReference {
        guard markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let directory = try locator.directory(relativeDirectory, in: root)
        let stem = try safeStem(title)
        var attempt = 1
        while attempt <= 10_000 {
            let suffix = attempt == 1 ? "" : " \(attempt)"
            let url = directory.appendingPathComponent(stem + suffix).appendingPathExtension("md")
            do {
                try exclusiveWrite(Data(markdown.utf8), to: url)
                let relativePath = try locator.relativePath(of: url, in: root)
                return NoteReference(rootID: root.id, relativePath: relativePath, fileIdentity: try locator.identity(of: url), available: true, modifiedAt: try locator.modifiedAt(url))
            } catch let error as POSIXError where error.code == .EEXIST {
                attempt += 1
            }
        }
        throw WorkStoreError.busy
    }

    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) throws -> NoteAppendProposal {
        guard markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let snapshot = try read(note, root: root, maxBytes: WorkLimits.noteBytes)
        guard !snapshot.truncated else { throw WorkStoreError.outputLimit }
        return NoteAppendProposal(note: note, root: root, expectedHash: snapshot.sha256, markdownToAppend: markdown, preview: snapshot.markdown + markdown)
    }

    func applyAppend(_ proposal: NoteAppendProposal) throws -> NoteFileSnapshot {
        guard proposal.markdownToAppend.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        let url = try locator.resolve(proposal.note, root: proposal.root)
        let current = try boundedRead(url, maxBytes: WorkLimits.noteBytes)
        guard !current.truncated, current.sha256 == proposal.expectedHash else { throw WorkStoreError.fileChanged }
        try coordinatedReplace(url, with: Data((current.markdown + proposal.markdownToAppend).utf8), expectedHash: proposal.expectedHash)
        return try read(proposal.note, root: proposal.root, maxBytes: WorkLimits.noteBytes)
    }

    private func safeStem(_ title: String) throws -> String {
        let stem = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty, stem.utf8.count <= 180, !stem.contains("/"), !stem.contains("\\"), stem != ".", stem != ".." else { throw WorkStoreError.invalidInput }
        return stem.hasSuffix(".md") ? String(stem.dropLast(3)) : stem
    }

    private func boundedRead(_ url: URL, maxBytes: Int) throws -> (markdown: String, sha256: String, truncated: Bool) {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) } catch { throw WorkStoreError.unavailable }
        defer { try? handle.close() }
        var digest = SHA256()
        var prefix = Data()
        var hasExtra = false
        while let chunk = try handle.read(upToCount: 16_384), !chunk.isEmpty {
            digest.update(data: chunk)
            if prefix.count <= maxBytes {
                let remaining = maxBytes + 1 - prefix.count
                prefix.append(chunk.prefix(remaining))
                if prefix.count > maxBytes { hasExtra = true }
            }
        }
        let truncated = hasExtra || prefix.count > maxBytes
        if prefix.count > maxBytes { prefix = prefix.prefix(maxBytes) }
        while !prefix.isEmpty && String(data: prefix, encoding: .utf8) == nil { prefix.removeLast() }
        guard let markdown = String(data: prefix, encoding: .utf8) else { throw WorkStoreError.invalidInput }
        return (markdown, digest.finalize().hexadecimal, truncated)
    }

    private func exclusiveWrite(_ data: Data, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            if errno == EEXIST { throw POSIXError(.EEXIST) }
            throw WorkStoreError.unavailable
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do { try handle.write(contentsOf: data); try handle.synchronize() }
        catch { throw WorkStoreError.unavailable }
    }

    private func coordinatedReplace(_ url: URL, with data: Data, expectedHash: String) throws {
        var coordinationError: NSError?
        var operationError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinatedURL in
            do {
                let current = try self.boundedRead(coordinatedURL, maxBytes: WorkLimits.noteBytes)
                guard !current.truncated, current.sha256 == expectedHash else { throw WorkStoreError.fileChanged }
                let handle = try FileHandle(forWritingTo: coordinatedURL)
                defer { try? handle.close() }
                try handle.truncate(atOffset: 0)
                try handle.write(contentsOf: data)
                try handle.synchronize()
            } catch { operationError = error }
        }
        if let operationError { throw (operationError as? WorkStoreError) ?? WorkStoreError.unavailable }
        if coordinationError != nil { throw WorkStoreError.unavailable }
    }
}

private extension SHA256Digest {
    var hexadecimal: String { map { String(format: "%02x", $0) }.joined() }
}
