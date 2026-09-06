import Testing
@testable import CiderPlatform

@Test func tableStylesUseBundledResourceRoute() {
    #expect(EditorResourcePolicy.isBundled("/cider-tables.css"))
    #expect(EditorResourcePolicy.isBundled("/dist/index.css"))
    #expect(!EditorResourcePolicy.isBundled("/note.assets/image.png"))
    #expect(!EditorResourcePolicy.isBundled("/arbitrary.css"))
}
