import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite struct TodoContextTests {
    @Test func contextIncludesOnlySelectedTaskAndMarksPreviewData() async throws {
        let fixture = try LinkedFixture.load()
        let repository = FixtureRepository(fixture)
        let task = try #require(fixture.tasks.first)
        let firstNote = try #require(fixture.notes.first)
        let notes = FixtureNoteAccess(bodies: [firstNote.id: "# Plan\nSaved evidence\n"])
        let reader = TodoContextReader(repository: repository, noteAccess: notes)

        let metadata = try await reader.context(taskID: task.id)
        #expect(metadata.notes.allSatisfy { $0.content == nil })
        #expect(metadata.detail.task.id == task.id)
        #expect(metadata.activity.items.allSatisfy { $0.taskID == task.id })
        #expect(metadata.activity.items.contains { $0.previewOnly })

        let expanded = try await reader.context(taskID: task.id, options: TodoContextOptions(includeNotes: true))
        #expect(expanded.notes.first(where: { $0.reference.id == firstNote.id })?.content == "# Plan\nSaved evidence\n")
        #expect(expanded.notes.contains { $0.unavailable }) // The fixture's second linked file is intentionally missing.
    }

    @Test func contextBoundsWholePayloadAndReportsTruncation() async throws {
        var fixture = try LinkedFixture.load()
        fixture.tasks[0].descriptionMarkdown = String(repeating: "d", count: 20_000)
        let repository = FixtureRepository(fixture)
        let note = try #require(fixture.notes.first)
        let reader = TodoContextReader(repository: repository, noteAccess: FixtureNoteAccess(bodies: [note.id: String(repeating: "n", count: 60_000)]))
        let bundle = try await reader.context(taskID: fixture.tasks[0].id, options: TodoContextOptions(includeNotes: true, totalByteLimit: 25_000))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        #expect(try encoder.encode(bundle).count < 25_000)
        #expect(bundle.truncated)
        #expect(bundle.notes.contains { $0.truncated || $0.content == nil })
    }

}
