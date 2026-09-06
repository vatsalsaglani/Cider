import SwiftUI
import CiderDomain
import CiderUI

struct TaskRow: View {
    let item: TaskItem
    let toggle: () -> Void
    let edit: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18)).foregroundStyle(item.completed ? CiderColor.accent : .secondary)
            }.buttonStyle(.plain).help(item.completed ? "Reopen task" : "Complete task")
                .accessibilityLabel((item.completed ? "Reopen " : "Complete ") + item.title)
            Button(action: edit) {
                Text(item.title).strikethrough(item.completed).foregroundStyle(item.completed ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Edit task")
            IconAction("Edit task", symbol: "ellipsis", action: edit)
        }.padding(.vertical, 12)
    }
}
