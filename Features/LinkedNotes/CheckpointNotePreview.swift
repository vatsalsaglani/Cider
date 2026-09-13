import SwiftUI
import CiderDomain
import CiderUI

/// Value-driven confirmation sheet. The scene coordinator saves an open editor before creating this proposal.
struct CheckpointNotePreview: View {
    let entry: JournalEntry
    let proposal: NoteAppendProposal
    let destination: String
    let onConfirm: (NoteAppendProposal) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save checkpoint to note").font(.title2.weight(.semibold))
            Label("Preview only — this is not a full agent response.", systemImage: "eye")
                .font(.callout).foregroundStyle(CiderColor.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.chat.map { "\($0.provider.title) · \($0.sessionID)" } ?? "Saved checkpoint")
                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                Text("Destination: \(destination)").font(.caption).foregroundStyle(.secondary)
            }
            Text("Markdown to add").font(.headline)
            ScrollView { Text(proposal.markdownToAppend).font(.body.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                .frame(minHeight: 140).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            HStack { Button("Cancel", role: .cancel, action: onCancel); Spacer(); Button("Append preview") { onConfirm(proposal) }.buttonStyle(CiderDialogButtonStyle(primary: true)) }
        }.padding(24).frame(width: 560, height: 440)
    }
}
