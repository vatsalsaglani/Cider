import Foundation
import CryptoKit
import CiderDomain

/// In-memory note access for consumer tests. No filesystem, bookmarks or user notes are read.
actor FixtureNoteAccess: LinkedNoteAccess {
    private var bodies: [UUID: String]
    init(bodies: [UUID: String] = [:]) { self.bodies = bodies }
    func replaceBody(noteID: UUID, markdown: String) { bodies[noteID] = markdown }
    func resolve(_ note: NoteReference, root: FolderReference) throws -> URL {
        guard note.rootID == root.id, root.available, note.available else { throw WorkStoreError.unavailable }
        guard !note.relativePath.isEmpty, !note.relativePath.hasPrefix("/"), !note.relativePath.split(separator: "/").contains("..") else { throw WorkStoreError.outsideRoot }
        return URL(fileURLWithPath: root.path, isDirectory: true).appending(path: note.relativePath)
    }
    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) throws -> NoteFileSnapshot {
        _ = try resolve(note, root: root)
        guard (1...WorkLimits.noteBytes).contains(maxBytes) else { throw WorkStoreError.invalidInput }
        guard let body = bodies[note.id] else { throw WorkStoreError.notFound }
        var bytes = Data(body.utf8).prefix(maxBytes)
        while String(data: bytes, encoding: .utf8) == nil { bytes = bytes.dropLast() }
        return NoteFileSnapshot(noteID: note.id, markdown: String(data: bytes, encoding: .utf8)!, sha256: hash(body), modifiedAt: Date(timeIntervalSinceReferenceDate: 0), truncated: body.utf8.count > maxBytes)
    }
    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) throws -> NoteReference {
        guard !title.isEmpty, !title.contains("/"), !title.contains("\\"), markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.invalidInput }
        let path = relativeDirectory.isEmpty ? title + ".md" : relativeDirectory + "/" + title + ".md"
        let note = NoteReference(rootID: root.id, relativePath: path)
        _ = try resolve(note, root: root); bodies[note.id] = markdown; return note
    }
    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) throws -> NoteAppendProposal {
        let snapshot = try read(note, root: root, maxBytes: WorkLimits.noteBytes)
        guard !snapshot.truncated, markdown.utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        return NoteAppendProposal(note: note, root: root, expectedHash: snapshot.sha256, markdownToAppend: markdown, preview: snapshot.markdown + markdown)
    }
    func applyAppend(_ proposal: NoteAppendProposal) throws -> NoteFileSnapshot {
        let current = try read(proposal.note, root: proposal.root, maxBytes: WorkLimits.noteBytes)
        guard !current.truncated, current.sha256 == proposal.expectedHash else { throw WorkStoreError.fileChanged }
        guard (current.markdown + proposal.markdownToAppend).utf8.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        bodies[proposal.note.id] = current.markdown + proposal.markdownToAppend
        return try read(proposal.note, root: proposal.root, maxBytes: WorkLimits.noteBytes)
    }
    func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) throws -> [NoteDocumentLink] {
        throw WorkStoreError.notImplemented // The actual parser belongs to 04; never fake a successful empty index.
    }
    private func hash(_ body: String) -> String { SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined() }
}
