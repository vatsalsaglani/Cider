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

    @Test func handlesMatchingCodeDelimitersPercentEscapesAndImageReferences() throws {
        let root = UUID()
        let source = NoteReference(id: UUID(), rootID: root, relativePath: "notes/source.md")
        let real = NoteReference(id: UUID(), rootID: root, relativePath: "notes/real.md")
        let inlineCode = NoteReference(id: UUID(), rootID: root, relativePath: "notes/inline.md")
        let fencedCode = NoteReference(id: UUID(), rootID: root, relativePath: "notes/fenced.md")
        let image = NoteReference(id: UUID(), rootID: root, relativePath: "notes/image.md")
        let escaped = NoteReference(id: UUID(), rootID: root, relativePath: "notes/file#name.md")
        let markdown = """
        [real](real.md)
        `` [inline](inline.md) ``
        ```md
        [fenced](fenced.md)
        ~~~
        [still fenced](fenced.md)
        ```
        ![reference image][image]
        [image]: image.md
        [escaped](file%23name.md#two%20words)
        """
        let links = try MarkdownLinkIndex.links(in: markdown, source: source, knownNotes: [source, real, inlineCode, fencedCode, image, escaped], rootID: root)
        #expect(links.count == 2)
        #expect(links.contains { $0.targetID == real.id })
        #expect(links.contains { $0.targetID == escaped.id && $0.fragment == "two words" })
    }

    @Test func duplicateNormalizedKnownPathsAreRecoverableInsteadOfArbitrary() throws {
        let root = UUID()
        let source = NoteReference(id: UUID(), rootID: root, relativePath: "source.md")
        let first = NoteReference(id: UUID(), rootID: root, relativePath: "target.md")
        let duplicate = NoteReference(id: UUID(), rootID: root, relativePath: "target.md")
        #expect(throws: WorkStoreError.conflict) {
            try MarkdownLinkIndex.links(in: "[target](target.md)", source: source, knownNotes: [source, first, duplicate], rootID: root)
        }
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
