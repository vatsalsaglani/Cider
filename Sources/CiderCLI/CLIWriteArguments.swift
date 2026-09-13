import Foundation
import CiderDomain

enum CLIWriteArguments {
    static func parse(group: String, verb: String, options: inout CLIOptions) throws -> CLIWriteCommand {
        var command: CLIWriteCommand
        var file: String?
        switch (group, verb) {
        case ("todo", "create"), ("todo", "update"), ("todo", "complete"), ("todo", "reopen"):
            command = CLIWriteCommand(operation: verb == "create" ? .createTask : .updateTask)
            if verb != "create" {
                command.taskID = try options.id()
                command.expectedRevision = try options.integer("--if-revision", minimum: 1)
            }
            command.title = try options.take("--title")
            file = try options.take("--description-file")
            if let day = try options.take("--day") {
                let parts = day.split(separator: "-").compactMap { Int($0) }
                guard day.count == 10, parts.count == 3 else { throw WorkStoreError.invalidInput }
                let data = try JSONSerialization.data(withJSONObject: ["year": parts[0], "month": parts[1], "day": parts[2]])
                guard let parsed = try? JSONDecoder().decode(LocalDay.self, from: data), parsed.id == day else { throw WorkStoreError.invalidInput }
                command.day = parsed
            }
            if verb == "complete" { command.status = .done }
            else if verb == "reopen" { command.status = .planned }
            else if let value = try options.take("--status") {
                guard let status = WorkTaskStatus(rawValue: value) else { throw WorkStoreError.invalidInput }
                command.status = status
            }
        case ("todo", "add-note"):
            command = CLIWriteCommand(operation: .journalNote); command.taskID = try options.id()
            file = try options.take("--markdown-file")
            guard file != nil else { throw WorkStoreError.invalidInput }
        case ("todo", "link-note"):
            command = CLIWriteCommand(operation: .linkNote); command.taskID = try options.id()
            command.noteID = try options.uuid("--note")
            guard let role = try options.take("--role"), let parsed = NoteRole(rawValue: role) else { throw WorkStoreError.invalidInput }
            command.role = parsed
        case ("note", "create"):
            command = CLIWriteCommand(operation: .createNote); command.title = try options.take("--title")
            command.rootID = try options.uuid("--folder"); file = try options.take("--markdown-file")
        case ("note", "update"), ("note", "append"):
            command = CLIWriteCommand(operation: verb == "update" ? .replaceNote : .appendNote)
            command.noteID = try options.id(); command.expectedHash = try options.take("--if-hash")
            file = try options.take("--markdown-file")
            guard file != nil else { throw WorkStoreError.invalidInput }
        default: throw WorkStoreError.invalidInput
        }
        // Reject flags/identities before reading a file or waiting on stdin.
        guard options.words.isEmpty, options.values.isEmpty else { throw WorkStoreError.invalidInput }
        if file != nil { command.markdown = "" }
        // Empty journal text is only validated after its bounded input has been read.
        if command.operation != .journalNote { try command.validate() }
        if let file { command.markdown = try readMarkdown(file) }
        try command.validate()
        return command
    }
    private static func readMarkdown(_ path: String) throws -> String {
        guard !path.isEmpty else { throw WorkStoreError.invalidInput }
        let handle = path == "-" ? FileHandle.standardInput : try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { if path != "-" { try? handle.close() } }
        var data = Data()
        while data.count <= WorkLimits.noteBytes {
            let chunk = try handle.read(upToCount: min(8192, WorkLimits.noteBytes + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= WorkLimits.noteBytes else { throw WorkStoreError.outputLimit }
        guard let text = String(data: data, encoding: .utf8) else { throw WorkStoreError.invalidInput }
        return text
    }
}
