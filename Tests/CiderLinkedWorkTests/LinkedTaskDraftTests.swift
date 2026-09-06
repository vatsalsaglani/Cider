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

    @MainActor @Test func conflictPreservesBothVersionsAndRebasedSaveSucceeds() async throws {
        let fixture = try LinkedFixture.load()
        let repository = FixtureRepository(fixture)
        let model = LinkedWorkModel(repository: repository, noteAccess: FixtureNoteAccess())
        var draft = TaskDraft(task: fixture.tasks[0])
        draft.descriptionMarkdown = "Keep this local text"
        var savedElsewhere = fixture.tasks[0]
        savedElsewhere.title = "Saved elsewhere"
        _ = try await repository.apply(WorkMutation(change: .saveTask(task: savedElsewhere)))

        #expect(await model.perform(try draft.saveMutation()) == false)
        let saved = try await repository.detail(fixture.tasks[0].id).task
        let conflict = TaskDraftConflict(local: draft, saved: saved)
        #expect(model.error?.contains("draft is still here") == true)
        #expect(conflict.local.descriptionMarkdown == "Keep this local text")
        #expect(conflict.saved.title == "Saved elsewhere")
        #expect(conflict.rebasedDraft.originalRevision == saved.revision)
        #expect(conflict.rebasedDraft.title == "Saved elsewhere")
        #expect(conflict.rebasedDraft.descriptionMarkdown == "Keep this local text")

        var editedAfterConflict = draft
        editedAfterConflict.descriptionMarkdown = "Keep this newer text typed after the conflict"
        editedAfterConflict.status = .readyForReview
        editedAfterConflict.criteria.append(WorkCriterion(text: "Check the merged version"))
        let comparison = conflict.comparison(using: editedAfterConflict)
        #expect(comparison.map(\.field) == ["Title", "Description", "Status", "Criteria"])
        #expect(comparison.first(where: { $0.field == "Description" })?.local == "Keep this newer text typed after the conflict")

        let rebased = conflict.rebasedDraft(using: editedAfterConflict)
        #expect(rebased.originalRevision == saved.revision)
        #expect(rebased.descriptionMarkdown == "Keep this newer text typed after the conflict")
        #expect(rebased.status == .readyForReview)
        #expect(rebased.criteria.count == fixture.tasks[0].criteria.count + 1)
        #expect(await model.perform(try rebased.saveMutation()))
        let resolved = try await repository.detail(fixture.tasks[0].id).task
        #expect(resolved.title == "Saved elsewhere")
        #expect(resolved.descriptionMarkdown == "Keep this newer text typed after the conflict")
        #expect(resolved.status == .readyForReview)
        #expect(resolved.criteria.count == fixture.tasks[0].criteria.count + 1)
        #expect(model.error == nil)
    }

    @Test func validationUsesStoreLimitsAndExplainsDraftIssues() {
        var whitespaceCriterion = TaskDraft(task: WorkTask(title: "Review", criteria: [WorkCriterion(text: "   ")]))
        #expect(whitespaceCriterion.validationMessage == "Each criterion needs text or should be removed.")
        whitespaceCriterion.criteria = []
        whitespaceCriterion.descriptionMarkdown = String(repeating: "x", count: 65_537)
        #expect(whitespaceCriterion.validationMessage == "Descriptions must be 64 KiB or smaller.")
    }
}
