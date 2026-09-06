import Foundation
import CoreGraphics
import Testing
@testable import CiderDomain
import CiderData

@Test func notchUsesDisplayOriginAndCameraCenter() {
    let display = DisplaySnapshot(frame: CGRect(x: -1800, y: 200, width: 1800, height: 1200), visibleFrame: CGRect(x: -1800, y: 260, width: 1800, height: 1100), scale: 2, cameraWidth: 180, cameraHeight: 38)
    let frame = NotchGeometry.frame(display: display, edge: .top, expanded: true, position: 0)
    #expect(frame.midX == -900)
    #expect(frame.maxY == 1400)
    let side = NotchGeometry.frame(display: display, edge: .right, expanded: true, position: 2)
    #expect(side.maxX == display.visibleFrame.maxX)
    #expect(side.maxY == display.visibleFrame.maxY)
}

@Test func localDaysSurviveDST() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let day = LocalDay(year: 2026, month: 3, day: 7)
    #expect(day.adding(1, calendar: calendar) == LocalDay(year: 2026, month: 3, day: 8))
    #expect(day.adding(2, calendar: calendar) == LocalDay(year: 2026, month: 3, day: 9))
}

@Test func malformedDayIsRejected() throws {
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(LocalDay.self, from: Data(#"{"year":2026,"month":2,"day":31}"#.utf8))
    }
}

@Test func persistenceSurvivesNewStoreAndIgnoresOldRevision() async throws {
    let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appending(path: "workspace.json")
    let store = SnapshotStore(url: url)
    var value = AppSnapshot()
    value.tasks.append(TaskItem(title: "Test persistence"))
    try await store.save(value, revision: 2)
    try await store.save(AppSnapshot(), revision: 1)
    let loaded = try await SnapshotStore(url: url).load()
    #expect(loaded.tasks == value.tasks)
    try Data("broken".utf8).write(to: url)
    await #expect(throws: (any Error).self) { try await SnapshotStore(url: url).load() }
    #expect(try String(contentsOf: url, encoding: .utf8) == "broken")
}

@Test func frontmatterPreservesCommentsAndLineEndings() {
    let input = "---\r\n# Keep me\r\ntitle: 'Unchanged'\r\n---\r\n# Heading\r\n"
    let parts = MarkdownParts(input)
    #expect(parts.header + parts.body == input)
    #expect(parts.header.contains("# Keep me\r\n"))
    #expect(parts.body == "# Heading\r\n")
}

@Test func notchShouldersReachTheEdge() {
    let rect = CGRect(x: 0, y: 0, width: 440, height: 320)
    let path = NotchOutline.path(in: rect, edge: .top)
    #expect(path.contains(CGPoint(x: 2, y: 0.01)))
    #expect(!path.contains(CGPoint(x: 2, y: 40)))
    #expect(path.contains(CGPoint(x: 220, y: 40)))
}

@Test func commandRunnerIsBounded() async throws {
    let output = try await CommandRunner.run("/usr/bin/printf", arguments: ["fixture"])
    #expect(String(data: output, encoding: .utf8) == "fixture")
    await #expect(throws: (any Error).self) { try await CommandRunner.run("/bin/sleep", arguments: ["2"], timeout: 0.1) }
}

@Test func quotaMissingIsNotZero() throws {
    let json = #"[{"provider":"codex","source":"oauth","usage":{"primary":{"usedPercent":28,"windowMinutes":300,"resetsAt":"2026-09-06T08:00:00Z"},"secondary":null,"updatedAt":"2026-09-06T02:00:00Z"}}]"#
    let value = try JSONDecoder().decode([ProviderUsage].self, from: Data(json.utf8))[0]
    #expect(value.quotas.count == 1)
    #expect(value.quotas.first?.usedPercent == 28)
    #expect(value.usage?.secondary == nil)
}
