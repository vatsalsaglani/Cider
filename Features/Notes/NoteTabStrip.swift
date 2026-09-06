import SwiftUI
import CiderUI

struct NoteTabStrip: View {
    @Bindable var notes: NotesModel
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(notes.tabs, id: \.self) { file in
                    HStack(spacing: 8) {
                        Button { Task { await notes.open(file) } } label: {
                            Label(file.lastPathComponent, systemImage: "doc.text").lineLimit(1).frame(maxWidth: 180)
                        }.buttonStyle(.plain).help(file.path)
                        Button { Task { await notes.close(file) } } label: { Image(systemName: "xmark").font(.system(size: 10)).frame(width: 20, height: 24) }
                            .buttonStyle(.plain).help("Close " + file.lastPathComponent)
                            .accessibilityLabel("Close " + file.lastPathComponent)
                    }.id(file)
                        .contextMenu {
                            Button("Close Tab") { Task { await notes.close(file) } }
                            Button("Reveal in Finder") { notes.reveal(file) }
                            Button("Copy Path") { notes.copyPath(file) }
                        }.font(.caption).padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 5)
                        .background(notes.selected == file ? Color.white.opacity(0.10) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(notes.selected == file ? 0.10 : 0.025)))
                }
            }.padding(.horizontal, 8).padding(.vertical, 2)
        }.scrollIndicators(.hidden).disabled(notes.opening)
        .onChange(of: notes.selected) { _, file in
            if let file { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(file, anchor: .trailing) } }
        }
        .onAppear { if let file = notes.selected { proxy.scrollTo(file, anchor: .trailing) } }
        }
    }
}
