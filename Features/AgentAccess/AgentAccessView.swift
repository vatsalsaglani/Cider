import AppKit
import SwiftUI
import CiderData
import CiderDomain
import CiderUI

/// A local, user-driven skill setup surface. It never changes a project until the
/// user presses the labelled install/update/remove action after reviewing a preview.
struct AgentAccessView: LinkedAgentAccessFeature {
    @State private var provider: WorkflowSkillProvider = .codex
    @State private var projectRoot: URL?
    @State private var executable: URL?
    @State private var preview: WorkflowSkillPreview?
    @State private var busy = false
    @State private var status: String = "Choose a project folder, then review the project-local skill change."
    private let setup = WorkflowSkillSetup()

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Agent access").font(.title2.weight(.semibold))
                Text("Install the Cider workflow skill only after reviewing its exact project-local destination and command.")
                    .foregroundStyle(.secondary)
                CiderPillPicker("Workflow provider", selection: $provider, options: WorkflowSkillProvider.allCases, title: providerTitle)
                    .frame(maxWidth: 300)
                    .onChange(of: provider) { _, _ in refreshPreview() }
                locationRow("Project", value: projectRoot?.path, action: chooseProject, label: "Choose project")
                locationRow("Cider CLI", value: executable?.path ?? packagedHelper()?.path, action: chooseExecutable, label: "Choose CLI")
                HStack {
                    Button("Review setup") { refreshPreview() }
                        .disabled(projectRoot == nil || busy)
                    if projectRoot != nil { Button("Review removal") { previewRemoval() }.disabled(busy) }
                }
                .buttonStyle(.bordered)
                previewPanel
                Text(status).font(.footnote).foregroundStyle(.secondary)
                Text("No global settings, hooks, credentials, notes, or TODOs are changed.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var previewPanel: some View {
        if let preview {
            GroupBox("Reviewed change") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(preview.destination.path).font(.caption.monospaced()).textSelection(.enabled)
                    Text(actionText(preview.action)).foregroundStyle(preview.action == .conflict || preview.action == .unavailable ? .orange : .secondary)
                    reviewedBytes("New managed bytes", preview.bytes)
                    if let existing = preview.existingBytes, existing != preview.bytes { reviewedBytes("Existing bytes", existing) }
                    actionButton(preview)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func reviewedBytes(_ title: String, _ bytes: Data) -> some View {
        if !bytes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(title) (\(bytes.count) bytes)").font(.caption.weight(.medium))
                ScrollView([.horizontal, .vertical]) {
                    Text(String(decoding: bytes, as: UTF8.self)).font(.caption.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder private func actionButton(_ preview: WorkflowSkillPreview) -> some View {
        switch preview.action {
        case .install: Button("Install skill") { apply(preview) }.buttonStyle(.borderedProminent).disabled(busy)
        case .update: Button("Update managed skill") { apply(preview) }.buttonStyle(.borderedProminent).disabled(busy)
        case .remove: Button("Remove managed skill", role: .destructive) { remove(preview) }.buttonStyle(.bordered).disabled(busy)
        case .alreadyInstalled: Text("The reviewed managed skill is already installed.")
        case .conflict: Text("An unrelated or edited skill is present; Cider will not overwrite or remove it.")
        case .unavailable: Text("Choose an executable Cider CLI. The packaged helper is unavailable at this app location.")
        }
    }

    private func locationRow(_ label: String, value: String?, action: @escaping () -> Void, label buttonLabel: String) -> some View {
        HStack(alignment: .top) {
            Text(label).frame(width: 70, alignment: .leading)
            Text(value ?? "Not chosen").font(.caption.monospaced()).foregroundStyle(value == nil ? .secondary : .primary).lineLimit(2)
            Spacer()
            Button(buttonLabel, action: action).buttonStyle(.bordered).disabled(busy)
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        projectRoot = url; refreshPreview()
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        executable = url; refreshPreview()
    }

    private func packagedHelper() -> URL? {
        let candidate = Bundle.main.bundleURL.appending(path: "Contents/Helpers/cider")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    private func refreshPreview() {
        guard let projectRoot, !busy else { return }
        let provider = provider; let executable = executable ?? packagedHelper(); let setup = setup
        busy = true; status = "Preparing a read-only preview…"
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<WorkflowSkillPreview, WorkStoreError> in
                do { return .success(try setup.preview(provider: provider, projectRoot: projectRoot, executable: executable)) }
                catch let error as WorkStoreError { return .failure(error) }
                catch { return .failure(.unavailable) }
            }.value
            busy = false
            switch result {
            case .success(let value): preview = value; status = "Preview only. Confirm the action below to change this project."
            case .failure(let error): status = "Unable to prepare a safe project-local preview: \(error.code)"
            }
        }
    }

    private func previewRemoval() {
        guard let projectRoot, !busy else { return }
        let provider = provider; let setup = setup
        busy = true; status = "Preparing a removal preview…"
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<WorkflowSkillPreview, WorkStoreError> in
                do { return .success(try setup.previewRemoval(provider: provider, projectRoot: projectRoot)) }
                catch let error as WorkStoreError { return .failure(error) }
                catch { return .failure(.unavailable) }
            }.value
            busy = false
            switch result {
            case .success(let value): preview = value; status = "Review removal before confirming it."
            case .failure(let error): status = "Unable to prepare removal: \(error.code)"
            }
        }
    }

    private func apply(_ preview: WorkflowSkillPreview) {
        guard !busy else { return }
        let setup = setup
        busy = true; status = "Applying the reviewed change…"
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<Void, WorkStoreError> in
                do { try setup.apply(preview); return .success(()) }
                catch let error as WorkStoreError { return .failure(error) }
                catch { return .failure(.unavailable) }
            }.value
            busy = false
            switch result {
            case .success: status = "Installed after explicit confirmation. Review the retained preview or create a fresh one."
            case .failure(let error): status = "Setup action did not complete (\(error.code)); inspect the destination before retrying."
            }
        }
    }

    private func remove(_ preview: WorkflowSkillPreview) {
        guard !busy else { return }
        let setup = setup
        busy = true; status = "Removing the reviewed managed skill…"
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<Void, WorkStoreError> in
                do { try setup.remove(preview); return .success(()) }
                catch let error as WorkStoreError { return .failure(error) }
                catch { return .failure(.unavailable) }
            }.value
            busy = false
            switch result {
            case .success: status = "Removed the reviewed managed skill. The preview remains for audit; refresh before another action."
            case .failure(let error): status = "Removal did not complete (\(error.code)); inspect the destination before retrying."
            }
        }
    }

    private func providerTitle(_ provider: WorkflowSkillProvider) -> String { provider == .codex ? "Codex" : "Claude Code" }
    private func actionText(_ action: WorkflowSkillAction) -> String { action.rawValue.capitalized }
}
