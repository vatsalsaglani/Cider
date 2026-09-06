import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite(.serialized) struct WorkflowSkillSetupTests {
    @Test func previewInstallUpdateAndManagedRemovalPreserveOtherFiles() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appending(path: "cider")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let setup = WorkflowSkillSetup()
        let install = try setup.preview(provider: .codex, projectRoot: root, executable: executable)
        #expect(install.action == .install)
        try setup.apply(install)
        let unrelated = root.appending(path: ".agents/skills/other/SKILL.md")
        try FileManager.default.createDirectory(at: unrelated.deletingLastPathComponent(), withIntermediateDirectories: true)
        let untouched = Data("other bytes".utf8); try untouched.write(to: unrelated)
        let update = try setup.preview(provider: .codex, projectRoot: root, executable: executable)
        #expect(update.action == .alreadyInstalled)
        try Data((String(decoding: install.bytes, as: UTF8.self) + "\n# user note\n").utf8).write(to: install.destination)
        let changed = try setup.preview(provider: .codex, projectRoot: root, executable: executable)
        #expect(changed.action == .update)
        try Data((String(decoding: changed.existingBytes ?? Data(), as: UTF8.self) + "# another edit\n").utf8).write(to: install.destination)
        #expect(throws: WorkStoreError.conflict) { try setup.apply(changed) }
        try install.bytes.write(to: install.destination)
        let removal = try setup.previewRemoval(provider: .codex, projectRoot: root)
        #expect(removal.action == .remove)
        try setup.remove(removal)
        #expect(!FileManager.default.fileExists(atPath: install.destination.path))
        #expect(try Data(contentsOf: unrelated) == untouched)
    }

    @Test func unrelatedSkillAndChangedManagedBytesAreNeverOverwritten() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appending(path: "cider")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let setup = WorkflowSkillSetup()
        let destination = root.appending(path: ".claude/skills/cider-workflow/SKILL.md")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("# Unrelated skill\n".utf8); try original.write(to: destination)
        let conflict = try setup.preview(provider: .claudeCode, projectRoot: root, executable: executable)
        #expect(conflict.action == .conflict)
        #expect(try Data(contentsOf: destination) == original)
        let unavailable = try setup.preview(provider: .codex, projectRoot: root, executable: nil)
        #expect(unavailable.action == .unavailable)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-skill-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
