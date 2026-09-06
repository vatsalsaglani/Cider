import Foundation

public protocol LinkedNoteAccess: Sendable {
    func resolve(_ note: NoteReference, root: FolderReference) async throws -> URL
    func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) async throws -> NoteFileSnapshot
    func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) async throws -> NoteReference
    func previewAppend(note: NoteReference, root: FolderReference, markdown: String) async throws -> NoteAppendProposal
    func applyAppend(_ proposal: NoteAppendProposal) async throws -> NoteFileSnapshot
    func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) async throws -> [NoteDocumentLink]
}

public struct NoteAppendProposal: Codable, Sendable, Equatable {
    public var id: UUID
    public var note: NoteReference
    public var root: FolderReference
    public var expectedHash: String
    public var markdownToAppend: String
    public var preview: String
    public init(
        id: UUID = UUID(),
        note: NoteReference,
        root: FolderReference,
        expectedHash: String,
        markdownToAppend: String,
        preview: String
    ) {
        self.id = id
        self.note = note
        self.root = root
        self.expectedHash = expectedHash
        self.markdownToAppend = markdownToAppend
        self.preview = preview
    }
}
