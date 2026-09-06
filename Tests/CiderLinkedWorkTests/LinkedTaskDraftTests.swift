import Foundation
import Testing
@testable import CiderData
import CiderDomain
import CiderUI

@Suite struct LinkedTaskDraftTests {
    @Test func draftRetainsTheRowRevisionWhenPreparingSave() throws {
        var task = WorkTask(title: "Review", descriptionMarkdown: "Before", status: .inProgress, revision: 7)
        task.criteria = [WorkCriterion(text: "Read the change")]
        var draft = TaskDraft(task: task)
        draft.title = "Review linked work"
        let saved = try draft.savedTask()
        #expect(saved.revision == 7)
        #expect(saved.title == "Review linked work")
        #expect(saved.status == .inProgress)
        #expect(try draft.saveMutation().expectedRevision == nil)
    }

    @Test func unrelatedEditsPreserveAnExplicitStatus() throws {
        let task = WorkTask(title: "Blocked task", status: .blocked, revision: 3)
        var draft = TaskDraft(task: task)
        draft.descriptionMarkdown = "Waiting on a decision"
        #expect(try draft.savedTask().status == .blocked)
        #expect(draft.criteriaProgress == nil)
    }

    @Test func checkboxOnlyChangesCompletionStateExplicitly() throws {
        var draft = TaskDraft(task: WorkTask(title: "Check", status: .readyForReview))
        draft.setCompleted(false)
        #expect(try draft.savedTask().status == .readyForReview)
        draft.setCompleted(true)
        #expect(try draft.savedTask().status == .done)
        draft.setCompleted(false)
        #expect(try draft.savedTask().status == .planned)
    }

    @MainActor @Test func staleSaveLeavesTheTypedDraftUntouched() async throws {
        let fixture = try LinkedFixture.load()
        let repository = FixtureRepository(fixture)
        let model = LinkedWorkModel(repository: repository, noteAccess: FixtureNoteAccess())
        var draft = TaskDraft(task: fixture.tasks[0])
        draft.descriptionMarkdown = "Keep this local text"
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: fixture.tasks[0])))

        #expect(await model.perform(try draft.saveMutation()) == false)
        #expect(draft.descriptionMarkdown == "Keep this local text")
        #expect(model.error?.contains("draft is still here") == true)
    }
}
