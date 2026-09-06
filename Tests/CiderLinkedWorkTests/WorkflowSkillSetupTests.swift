import Foundation
import Testing
@testable import CiderData
import CiderDomain

@Suite(.serialized) struct WorkflowSkillSetupTests {
    @Test func reviewedInstallUpdateAndRemovalPreserveOtherFiles() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let executable = try makeExecutable(root, name: "cider one")
        let setup = WorkflowSkillSetup()
        let install = try setup.preview(provider: .codex, projectRoot: root, executable: executable)
        #expect(install.action == .install)
        #expect(String(decoding: install.bytes, as: UTF8.self).hasPrefix("---\n"))
        try setup.apply(install)
        let unrelated = root.appending(path: ".agents/skills/other/SKILL.md")
        try FileManager.default.createDirectory(at: unrelated.deletingLastPathComponent(), withIntermediateDirectories: true)
        let untouched = Data("other bytes".utf8); try untouched.write(to: unrelated)

        let movedExecutable = try makeExecutable(root, name: "cider two")
        let update = try setup.preview(provider: .codex, projectRoot: root, executable: movedExecutable)
        #expect(update.action == .update)
        try setup.apply(update)
        let removal = try setup.previewRemoval(provider: .codex, projectRoot: root)
        #expect(removal.action == .remove)
        try setup.remove(removal)
        #expect(!FileManager.default.fileExists(atPath: install.destination.path))
        #expect(try Data(contentsOf: unrelated) == untouched)
    }

    @Test func markerOrByteChangesNeverAuthorizeOverwriteOrRemoval() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let executable = try makeExecutable(root, name: "cider")
        let setup = WorkflowSkillSetup()
        let install = try setup.preview(provider: .claudeCode, projectRoot: root, executable: executable)
        try setup.apply(install)
        try Data((String(decoding: install.bytes, as: UTF8.self) + "\n# user edit\n").utf8).write(to: install.destination)
        #expect(try setup.preview(provider: .claudeCode, projectRoot: root, executable: executable).action == .conflict)
        #expect(try setup.previewRemoval(provider: .claudeCode, projectRoot: root).action == .conflict)

        let managedLooking = Data("---\nname: unrelated\n---\n<!-- \(WorkflowSkillSetup.managedMarker) sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -->\n".utf8)
        try managedLooking.write(to: install.destination)
        #expect(try setup.preview(provider: .claudeCode, projectRoot: root, executable: executable).action == .conflict)
    }

    @Test func escapedIntermediateSymlinkAndOversizedExistingSkillAreRejected() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let external = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: external) }
        let executable = try makeExecutable(root, name: "cider")
        try FileManager.default.createSymbolicLink(at: root.appending(path: ".agents"), withDestinationURL: external)
        let setup = WorkflowSkillSetup()
        #expect(throws: WorkStoreError.outsideRoot) { try setup.preview(provider: .codex, projectRoot: root, executable: executable) }
        try FileManager.default.removeItem(at: root.appending(path: ".agents"))
        let destination = root.appending(path: ".agents/skills/cider-workflow/SKILL.md")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: WorkflowSkillSetup.maximumSkillBytes + 1).write(to: destination)
        #expect(throws: WorkStoreError.outputLimit) { try setup.preview(provider: .codex, projectRoot: root, executable: executable) }
    }

    @Test func shellQuoteRoundTripsSpacesAndApostrophes() throws {
        let original = "/tmp/Cider user's helper"
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf %s \(WorkflowSkillSetup.shellQuote(original))"]
        let output = Pipe(); process.standardOutput = output
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) == original)
    }

    private func makeExecutable(_ root: URL, name: String) throws -> URL {
        let executable = root.appending(path: name)
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return executable
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "cider-skill-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
