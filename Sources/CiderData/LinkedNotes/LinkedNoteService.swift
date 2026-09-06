import Foundation
import CiderDomain

/// Contract seed. Plan 04 adds root-scoped file access; these methods have no side effects.
public struct LinkedNoteService: LinkedNoteAccess {
    public init() {}
    public func resolve(_ note: NoteReference, root: FolderReference) async throws -> URL { throw WorkStoreError.notImplemented }
    public func read(_ note: NoteReference, root: FolderReference, maxBytes: Int) async throws -> NoteFileSnapshot { throw WorkStoreError.notImplemented }
    public func create(root: FolderReference, relativeDirectory: String, title: String, markdown: String) async throws -> NoteReference { throw WorkStoreError.notImplemented }
    public func previewAppend(note: NoteReference, root: FolderReference, markdown: String) async throws -> NoteAppendProposal { throw WorkStoreError.notImplemented }
    public func applyAppend(_ proposal: NoteAppendProposal) async throws -> NoteFileSnapshot { throw WorkStoreError.notImplemented }
    public func documentLinks(note: NoteReference, root: FolderReference, knownNotes: [NoteReference], maxBytes: Int) async throws -> [NoteDocumentLink] { throw WorkStoreError.notImplemented }
}
