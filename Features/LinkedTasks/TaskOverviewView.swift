import SwiftUI
import CiderDomain
import CiderUI

struct TaskOverviewView: View {
    @Binding var draft: TaskDraft
    let hasChanges: Bool
    let saving: Bool
    let validationMessage: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
                TextField("Untitled task", text: $draft.title, axis: .vertical)
                    .font(.system(size: 30, weight: .semibold)).textFieldStyle(.plain)
                    .padding(.trailing, 48).accessibilityLabel("Task title")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { metadata }
                    VStack(alignment: .leading, spacing: 12) { metadata }
                }
                TextField("Add a description…", text: $draft.descriptionMarkdown, axis: .vertical)
                    .font(.system(size: 15)).lineSpacing(6).textFieldStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Task description")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Acceptance criteria").font(.headline)
                        Spacer()
                        IconAction("Add criterion", symbol: "plus") { draft.addCriterion() }
                    }
                    if draft.criteria.isEmpty { Text("Add the checks that will make this task complete.").foregroundStyle(.secondary) }
                    ForEach(draft.criteria) { criterion in
                        HStack {
                            Toggle("Criterion complete", isOn: criterionCompletion(criterion)).labelsHidden()
                            TextField("Criterion", text: criterionText(criterion)).textFieldStyle(.plain)
                            IconAction("Remove criterion", symbol: "minus.circle") { draft.removeCriterion(id: criterion.id) }
                        }
                    }
                }
                if hasChanges { HStack {
                    Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                    if let validationMessage { Text(validationMessage).font(.caption).foregroundStyle(CiderColor.warning) }
                    Spacer()
                    Button("Save changes", action: onSave)
                        .buttonStyle(CiderDialogButtonStyle(primary: true))
                        .disabled(validationMessage != nil || saving)
                } }
        }.disabled(saving)
    }

    @ViewBuilder private var metadata: some View {
        Menu {
            ForEach(WorkTaskStatus.allCases, id: \.self) { status in
                Button(statusTitle(status)) { draft.status = status }
            }
        } label: {
            Label(statusTitle(draft.status), systemImage: draft.status == .done ? "checkmark.circle.fill" : "circle")
                .font(.caption).foregroundStyle(CiderColor.accent)
        }.menuStyle(.borderlessButton).fixedSize()
        DatePicker("Planned day", selection: plannedDay, displayedComponents: .date)
            .labelsHidden().datePickerStyle(.field).fixedSize().help("Planned day")
        if draft.dueAt != nil {
            DatePicker("Due date", selection: dueDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden().fixedSize().help("Due date")
            Button { draft.dueAt = nil } label: { Image(systemName: "xmark.circle") }
                .buttonStyle(.plain).help("Remove due date").accessibilityLabel("Remove due date")
        } else {
            Button("Add due date", systemImage: "plus") { draft.dueAt = .now }
                .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }

    private var plannedDay: Binding<Date> {
        Binding(get: { draft.plannedDay.date() }, set: { draft.plannedDay = LocalDay($0) })
    }
    private var hasDueDate: Binding<Bool> {
        Binding(get: { draft.dueAt != nil }, set: { draft.dueAt = $0 ? (draft.dueAt ?? .now) : nil })
    }
    private var dueDate: Binding<Date> {
        Binding(get: { draft.dueAt ?? .now }, set: { draft.dueAt = $0 })
    }
    private var completion: Binding<Bool> {
        Binding(get: { draft.status == .done }, set: { draft.setCompleted($0) })
    }
    private func criterionCompletion(_ criterion: WorkCriterion) -> Binding<Bool> {
        Binding(get: { draft.criteria.first(where: { $0.id == criterion.id })?.checked ?? false },
                set: { draft.setCriterionChecked($0, id: criterion.id) })
    }
    private func criterionText(_ criterion: WorkCriterion) -> Binding<String> {
        Binding(get: { draft.criteria.first(where: { $0.id == criterion.id })?.text ?? "" }, set: { text in
            guard let index = draft.criteria.firstIndex(where: { $0.id == criterion.id }) else { return }
            draft.criteria[index].text = text
        })
    }
    private func statusTitle(_ status: WorkTaskStatus) -> String {
        switch status {
        case .planned: "Planned"
        case .inProgress: "In progress"
        case .blocked: "Blocked"
        case .readyForReview: "Ready for review"
        case .done: "Done"
        }
    }
}
