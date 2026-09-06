import SwiftUI

public struct TaskComposer: View {
    @Binding var text: String
    let prompt: String
    let submit: () -> Void
    @FocusState private var focused: Bool
    let autofocus: Bool
    public init(text: Binding<String>, prompt: String = "Add a task…", autofocus: Bool = false, submit: @escaping () -> Void) {
        _text = text; self.prompt = prompt; self.autofocus = autofocus; self.submit = submit
    }
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus").foregroundStyle(.secondary)
            TextField(prompt, text: $text).textFieldStyle(.plain).focused($focused).onSubmit(submit)
                .accessibilityLabel("Task title")
            IconAction("Add task", symbol: "arrow.up", primary: true, action: submit)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .background(CiderColor.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .task { if autofocus { focused = true } }
    }
}
