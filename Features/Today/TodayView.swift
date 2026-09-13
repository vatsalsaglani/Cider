import SwiftUI
import CiderDomain
import CiderUI

struct TodayView: View {
    @Bindable var model: AppModel
    var openTask: ((UUID) -> Void)?
    @Binding var selectedDate: Date
    @State private var calendarMode = false
    @State private var month = Date.now
    @State private var editing: TaskItem?
    private var day: LocalDay { LocalDay(selectedDate) }
    private var tasks: [TaskItem] { model.tasks(on: day) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Calendar.current.isDateInToday(selectedDate) ? "Today" : "Your day").foregroundStyle(CiderColor.accentEnd)
                        Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.system(size: 28, weight: .semibold))
                        Text("\(tasks.filter { !$0.completed }.count) to do · \(tasks.filter(\.completed).count) completed").foregroundStyle(.secondary)
                    }
                    Spacer()
                    IconAction(calendarMode ? "List view" : "Calendar view", symbol: calendarMode ? "list.bullet" : "calendar") { calendarMode.toggle() }
                }
                if calendarMode { MonthCalendar(date: $selectedDate, month: $month, tasks: model.snapshot.tasks) }
                else { WeekStrip(date: $selectedDate) }
                TaskComposer(text: $model.dayDraft) {
                    let text = model.dayDraft
                    Task { if await model.createTask(text, day: day) { model.dayDraft = "" } }
                }.disabled(model.saving || !model.ready)
                if tasks.isEmpty { ContentUnavailableView("A little room to breathe", systemImage: "checkmark.circle", description: Text("Add something you’d like to finish.")).frame(maxWidth: .infinity).frame(minHeight: 210) }
                else {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks.filter { !$0.completed }) { item in row(item); Divider().opacity(0.3) }
                        if tasks.contains(where: \.completed) {
                            DisclosureGroup("Completed") {
                                ForEach(tasks.filter(\.completed)) { item in row(item) }
                            }.foregroundStyle(.secondary).padding(.top, 18)
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
        }
        .onChange(of: selectedDate) { _, value in month = value }
        .sheet(item: $editing) { item in TaskEditView(model: model, original: item).ciderDialog() }
    }
    private func row(_ item: TaskItem) -> some View {
        TaskRow(item: item, toggle: { Task { await model.toggle(item) } }, edit: { if let openTask { openTask(item.id) } else { editing = item } }).disabled(model.saving)
    }
}

struct TaskEditView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var item: TaskItem
    @State private var date: Date
    init(model: AppModel, original: TaskItem) { self.model = model; _item = State(initialValue: original); _date = State(initialValue: original.plannedDay.date()) }
    var body: some View {
        Form {
            TextField("Task", text: $item.title)
            DatePicker("Planned day", selection: $date, displayedComponents: .date)
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                IconAction("Save task", symbol: "checkmark", primary: true) {
                    item.plannedDay = LocalDay(date)
                    Task { if await model.update(item) { dismiss() } }
                }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.saving)
            }
        }.padding(24).frame(width: 390)
    }
}
