import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite(.serialized) struct LinkedNoteTests {
    @Test func rootContainmentRejectsSymlinksTraversalAndSiblingPrefixes() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let external = try temporaryRoot(); defer { remove(external) }
        let externalFile = external.appending(path: "outside.md")
        try Data("outside".utf8).write(to: externalFile)
        try FileManager.default.createSymbolicLink(at: rootURL.appending(path: "escape.md"), withDestinationURL: externalFile)
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let escaped = NoteReference(rootID: root.id, relativePath: "escape.md")
        await #expect(throws: WorkStoreError.outsideRoot) { try await service.resolve(escaped, root: root) }
        let traversal = NoteReference(rootID: root.id, relativePath: "../\(external.lastPathComponent)/outside.md")
        await #expect(throws: WorkStoreError.outsideRoot) { try await service.resolve(traversal, root: root) }
        let sibling = rootURL.deletingLastPathComponent().appending(path: rootURL.lastPathComponent + "-other")
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true); defer { remove(sibling) }
        try Data("other".utf8).write(to: sibling.appending(path: "note.md"))
        let siblingPath = NoteReference(rootID: root.id, relativePath: "../\(sibling.lastPathComponent)/note.md")
        await #expect(throws: WorkStoreError.outsideRoot) { try await service.resolve(siblingPath, root: root) }
    }

    @Test func creationUsesExclusiveNamesAndIdentitySurvivesExplicitRenameRepair() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let first = try await service.create(root: root, relativeDirectory: "", title: "Plan", markdown: "# Plan\n")
        let second = try await service.create(root: root, relativeDirectory: "", title: "Plan", markdown: "# Another\n")
        #expect(first.relativePath == "Plan.md")
        #expect(second.relativePath == "Plan 2.md")
        #expect(first.fileIdentity != nil)
        let renamed = rootURL.appending(path: "Renamed.md")
        try FileManager.default.moveItem(at: rootURL.appending(path: first.relativePath), to: renamed)
        await #expect(throws: WorkStoreError.notFound) { try await service.resolve(first, root: root) }
        let repaired = NoteReference(id: first.id, rootID: root.id, relativePath: "Renamed.md", fileIdentity: first.fileIdentity)
        #expect(try await service.resolve(repaired, root: root) == renamed)
    }

    @Test func appendRefusesExternalChangeAndBoundedReadsPreserveUTF8() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let note = try await service.create(root: root, relativeDirectory: "", title: "Evidence", markdown: "héllo\n")
        let limited = try await service.read(note, root: root, maxBytes: 4)
        #expect(limited.markdown == "hél")
        #expect(limited.truncated)
        let proposal = try await service.previewAppend(note: note, root: root, markdown: "checkpoint\n")
        try Data("external edit\n".utf8).write(to: rootURL.appending(path: note.relativePath))
        await #expect(throws: WorkStoreError.fileChanged) { try await service.applyAppend(proposal) }
        #expect(try String(contentsOf: rootURL.appending(path: note.relativePath), encoding: .utf8) == "external edit\n")
    }

    @Test func confirmedAppendKeepsTheStableFileReferenceUsable() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let note = try await service.create(root: root, relativeDirectory: "", title: "Checkpoint", markdown: "before\n")
        let proposal = try await service.previewAppend(note: note, root: root, markdown: "after\n")
        #expect(try await service.applyAppend(proposal).markdown == "before\nafter\n")
        #expect(try await service.read(note, root: root, maxBytes: WorkLimits.noteBytes).markdown == "before\nafter\n")
        let replacement = rootURL.appending(path: "external-replacement.md")
        try Data("external\n".utf8).write(to: replacement)
        _ = try FileManager.default.replaceItemAt(rootURL.appending(path: note.relativePath), withItemAt: replacement)
        await #expect(throws: WorkStoreError.notFound) { try await service.resolve(note, root: root) }
    }

    @Test func failedAtomicAppendLeavesOriginalBytesUntouched() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let writer = LinkedNoteService()
        let note = try await writer.create(root: root, relativeDirectory: "", title: "Safe", markdown: "original\n")
        let proposal = try await writer.previewAppend(note: note, root: root, markdown: "addition\n")
        let faulting = LinkedNoteService(testingReplacementFailure: true)
        await #expect(throws: WorkStoreError.unavailable) { try await faulting.applyAppend(proposal) }
        #expect(try Data(contentsOf: rootURL.appending(path: note.relativePath)) == Data("original\n".utf8))
    }

    @Test func rejectsMalformedUTF8AndOversizedFilesBeforeReturningContent() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let malformed = try await service.create(root: root, relativeDirectory: "", title: "Malformed", markdown: "valid")
        try Data([0xFF, 0xFE]).write(to: rootURL.appending(path: malformed.relativePath))
        await #expect(throws: WorkStoreError.invalidInput) { try await service.read(malformed, root: root, maxBytes: 10) }
        let large = try await service.create(root: root, relativeDirectory: "", title: "Large", markdown: "ok")
        try Data(repeating: 0x61, count: WorkLimits.noteBytes + 1).write(to: rootURL.appending(path: large.relativePath))
        await #expect(throws: WorkStoreError.outputLimit) { try await service.read(large, root: root, maxBytes: 10) }
    }

    @Test func bookmarkAndFileIdentifierCannotDistinguishReplacementOriginsAfterRestart() throws {
        let coordinated = try replacementOutcome(coordinated: true)
        let external = try replacementOutcome(coordinated: false)
        #expect(coordinated.stale && external.stale)
        #expect(coordinated.identifierChanged && external.identifierChanged)
        #expect(coordinated.resolvedReplacement && external.resolvedReplacement)
    }

    @Test func attachAndIndexLeaveMarkdownBytesUntouched() async throws {
        let rootURL = try temporaryRoot(); defer { remove(rootURL) }
        let root = FolderReference(path: rootURL.path)
        let service = LinkedNoteService()
        let source = try await service.create(root: root, relativeDirectory: "", title: "Source", markdown: "[Evidence](Evidence.md#check)\n")
        let target = try await service.create(root: root, relativeDirectory: "", title: "Evidence", markdown: "# Evidence\n")
        let before = try Data(contentsOf: rootURL.appending(path: source.relativePath))
        let links = try await service.documentLinks(note: source, root: root, knownNotes: [source, target], maxBytes: WorkLimits.noteBytes)
        #expect(links.count == 1)
        #expect(links[0].targetID == target.id)
        #expect(try Data(contentsOf: rootURL.appending(path: source.relativePath)) == before)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-linked-note-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func replacementOutcome(coordinated: Bool) throws -> (stale: Bool, identifierChanged: Bool, resolvedReplacement: Bool) {
        let root = try temporaryRoot(); defer { remove(root) }
        let note = root.appending(path: "note.md")
        let candidate = root.appending(path: "candidate.md")
        try Data("before".utf8).write(to: note)
        let bookmark = try note.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let before = String(describing: try note.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier)
        try Data("after".utf8).write(to: candidate)
        if coordinated {
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(writingItemAt: note, options: .forReplacing, error: &error) { coordinatedURL in
                _ = try? FileManager.default.replaceItemAt(coordinatedURL, withItemAt: candidate)
            }
            guard error == nil else { throw WorkStoreError.unavailable }
        } else {
            _ = try FileManager.default.replaceItemAt(note, withItemAt: candidate)
        }
        let after = String(describing: try note.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier)
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        return (stale, before != after, resolved.standardizedFileURL == note.standardizedFileURL)
    }

    private func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }
}
