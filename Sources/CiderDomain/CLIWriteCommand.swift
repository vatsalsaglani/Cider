import Foundation

/// Closed CLI write vocabulary. Note text is payload, never executable instructions.
public struct CLIWriteCommand: Codable, Equatable, Sendable {
    public enum Operation: String, Codable, Sendable { case createTask, updateTask, journalNote, createNote, replaceNote, appendNote, linkNote }
    public var operation: Operation
    public var taskID: UUID?
    public var noteID: UUID?
    public var rootID: UUID?
    public var title: String?
    public var markdown: String?
    public var day: LocalDay?
    public var status: WorkTaskStatus?
    public var expectedRevision: Int64?
    public var expectedHash: String?
    public var role: NoteRole?
    public init(operation: Operation) { self.operation = operation }
    public func validate() throws {
        guard markdown?.utf8.count ?? 0 <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        if let title { guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 500 else { throw WorkStoreError.invalidInput } }
        if operation == .createNote, let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let stem = trimmed.hasSuffix(".md") ? String(trimmed.dropLast(3)) : trimmed
            guard !stem.isEmpty, stem != ".", stem != "..", trimmed.utf8.count <= 180,
                  !trimmed.contains("/"), !trimmed.contains("\\"),
                  !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw WorkStoreError.invalidInput }
        }
        switch operation {
        case .createTask, .createNote: guard title != nil else { throw WorkStoreError.invalidInput }
        case .updateTask:
            guard taskID != nil, let expectedRevision, expectedRevision > 0,
                  title != nil || markdown != nil || day != nil || status != nil else { throw WorkStoreError.invalidInput }
        case .journalNote: guard taskID != nil, let markdown, !markdown.isEmpty, markdown.utf8.count <= 16_384 else { throw WorkStoreError.invalidInput }
        case .replaceNote, .appendNote:
            guard noteID != nil, markdown != nil, let expectedHash, expectedHash.count == 64,
                  expectedHash.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw WorkStoreError.invalidInput }
        case .linkNote: guard taskID != nil, noteID != nil, role != nil else { throw WorkStoreError.invalidInput }
        }
    }
}

public struct CLIWriteReply: Codable, Sendable {
    public var revision: Int64 = 0
    public var task: WorkTask?
    public var note: NoteReference?
    public var sha256: String?
    public var path: String?
    public var error: WorkStoreError?
    /// A file was saved but metadata could not finish; inspect this path before retrying.
    public var partialWrite = false
    public init() {}
}

public struct CLIWriteRequest: Codable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public let leaseID: UUID
    public let createdAt: Date
    public let command: CLIWriteCommand
    public init(leaseID: UUID, command: CLIWriteCommand) {
        schemaVersion = 1; id = UUID(); self.leaseID = leaseID; createdAt = .now; self.command = command
    }
}
