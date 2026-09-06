import SwiftUI
import CiderDomain
import CiderUI

struct TaskOverviewView: View {
    @Binding var draft: TaskDraft
    let saving: Bool
    let validationMessage: String?
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $draft.title)
                DatePicker("Planned day", selection: plannedDay, displayedComponents: .date)
                Toggle("Due date", isOn: hasDueDate)
                if draft.dueAt != nil {
                    DatePicker("Due", selection: dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            Section("Status") {
                CiderPillPicker("Task status", selection: $draft.status,
                                options: WorkTaskStatus.allCases, title: statusTitle)
                    .frame(maxWidth: 620)
                Toggle("Completed", isOn: completion)
                    .help("Mark this task complete or reopen it")
            }
            Section("Description") {
                TextEditor(text: $draft.descriptionMarkdown)
                    .font(.body.monospaced())
                    .frame(minHeight: 150)
                    .accessibilityLabel("Description Markdown source")
                Text("Markdown source is saved with this task.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Criteria") {
                if draft.criteria.isEmpty {
                    Text("No criteria yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(draft.criteria) { criterion in
                        HStack {
                            Toggle("Criterion complete", isOn: criterionCompletion(criterion)).labelsHidden()
                            TextField("Criterion", text: criterionText(criterion))
                            IconAction("Remove criterion", symbol: "minus.circle") { draft.removeCriterion(id: criterion.id) }
                        }
                    }
                    if let progress = draft.criteriaProgress {
                        Text("\(Int(progress * 100))% of criteria checked").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Add criterion", systemImage: "plus") { draft.addCriterion() }
            }
            HStack {
                Spacer()
                Button("Save changes") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .tint(CiderColor.accent)
                    .disabled(validationMessage != nil || saving)
            }
            if let validationMessage {
                Text(validationMessage).font(.caption).foregroundStyle(CiderColor.warning)
            }
        }
        .formStyle(.grouped)
        .disabled(saving)
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
