import Foundation

public enum DefaultNotesFolder {
    public static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "Cider", directoryHint: .isDirectory)
    }

    /// Called only by New Note when there are no workspace roots.
    public static func prepare(at url: URL) async throws -> URL {
        try await AgentIO.run {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { throw CocoaError(.fileWriteInvalidFileName) }
            return url.standardizedFileURL
        }
    }

    public static func createNote(in folder: URL) async throws -> URL {
        try await AgentIO.run {
            let url = folder.appending(path: "Note-\(UUID().uuidString.prefix(8)).md")
            try Data().write(to: url, options: .withoutOverwriting)
            return url
        }
    }
}
