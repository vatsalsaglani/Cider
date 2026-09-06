import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite struct MarkdownLinkIndexTests {
    @Test func indexesRelativeReferenceEscapedAndDistinctFragmentsOnly() throws {
        let root = UUID()
        let source = NoteReference(id: UUID(), rootID: root, relativePath: "plans/source.md")
        let evidence = NoteReference(id: UUID(), rootID: root, relativePath: "evidence/final note.md")
        let parent = NoteReference(id: UUID(), rootID: root, relativePath: "review.md")
        let markdown = """
        [first](../evidence/final%20note.md#one)
        [second](../evidence/final%20note.md#two)
        [review]: ../review.md#decision
        [reference][review]
        """
        let links = try MarkdownLinkIndex.links(in: markdown, source: source, knownNotes: [source, evidence, parent], rootID: root)
        #expect(links.count == 3)
        #expect(Set(links.filter { $0.targetID == evidence.id }.map(\.fragment)) == Set(["one", "two"]))
        #expect(links.contains { $0.targetID == parent.id && $0.fragment == "decision" })
        #expect(Set(links.map(\.id)).count == 3)
    }

    @Test func ignoresCodeImagesRemoteAndUnavailableTargets() throws {
        let root = UUID()
        let source = NoteReference(id: UUID(), rootID: root, relativePath: "notes/source.md")
        let target = NoteReference(id: UUID(), rootID: root, relativePath: "notes/target.md")
        let markdown = """
        [real](target.md)
        ![image](target.md)
        ` [inline](target.md) `
        ```md
        [fenced](target.md)
        ```
        [web](https://example.com/target.md)
        [missing](missing.md)
        """
        let links = try MarkdownLinkIndex.links(in: markdown, source: source, knownNotes: [source, target], rootID: root)
        #expect(links.count == 1)
        #expect(links[0].targetID == target.id)
    }

    @Test func outputIsDeterministicAndDoesNotTreatBasenamesAsReferences() throws {
        let root = UUID()
        let source = NoteReference(id: UUID(), rootID: root, relativePath: "a/source.md")
        let wanted = NoteReference(id: UUID(), rootID: root, relativePath: "a/target.md")
        let other = NoteReference(id: UUID(), rootID: root, relativePath: "b/target.md")
        let markdown = "[target](target.md#same) [target again](target.md#same)"
        let once = try MarkdownLinkIndex.links(in: markdown, source: source, knownNotes: [source, wanted, other], rootID: root)
        let twice = try MarkdownLinkIndex.links(in: markdown, source: source, knownNotes: [other, wanted, source], rootID: root)
        #expect(once.count == 1)
        #expect(once[0].targetID == wanted.id)
        #expect(once == twice)
    }
}
