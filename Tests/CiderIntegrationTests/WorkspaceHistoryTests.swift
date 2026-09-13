import Foundation
import Testing
import CiderDomain
import CiderUI
@testable import CiderApp

@MainActor struct WorkspaceHistoryTests {
    @Test func taskNoteRoundTripAndBranching() {
        let history = WorkspaceHistory()
        let task = WorkspaceLocation(section: "Today", task: UUID())
        let note = WorkspaceLocation(section: "Notes", note: URL(fileURLWithPath: "/fixture/plan.md"))
        history.record(task); history.record(note)
        #expect(history.destination(-1) == task)
        #expect(history.parentTask?.id == task.task)
        #expect(history.parentTask?.offset == -1)
        history.move(-1)
        #expect(history.destination(1) == note)
        history.record(task)
        #expect(history.canGoForward)
        history.record(WorkspaceLocation(section: "Graph"))
        #expect(!history.canGoForward)
        #expect(history.destination(-1) == task)
    }
    @Test func boundariesAndBoundedHistory() {
        let history = WorkspaceHistory()
        history.move(-1)
        #expect(history.index == 0)
        for _ in 0..<120 { history.record(WorkspaceLocation(task: UUID())) }
        #expect(history.entries.count == 100)
        #expect(history.index == 99)
        #expect(history.destination(1) == nil)
    }
    @Test func taskDraftAndSectionSurviveAnotherDestination() {
        let sessions = TaskDetailSessions()
        let task = WorkTask(title: "Saved title")
        let session = sessions.session(task.id)
        session.draft = TaskDraft(task: task)
        session.draft?.title = "Unsaved title"
        session.section = .notes
        _ = sessions.session(UUID())
        #expect(sessions.session(task.id) === session)
        #expect(sessions.session(task.id).draft?.title == "Unsaved title")
        #expect(sessions.session(task.id).section == .notes)
    }
}
