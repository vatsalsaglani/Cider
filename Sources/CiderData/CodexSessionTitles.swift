import Foundation

/// Read-only names for already observed sessions. Never opens rollouts or auth files.
public enum CodexSessionTitles {
    public static func load(index: URL, sessions: Set<String>, byteLimit: Int = 4 * 1024 * 1024) throws -> [String: String] {
        guard !sessions.isEmpty, byteLimit > 0 else { return [:] }
        let values = try index.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { return [:] }
        let file = try FileHandle(forReadingFrom: index)
        defer { try? file.close() }
        let length = try file.seekToEnd()
        let offset = length > UInt64(byteLimit) ? length - UInt64(byteLimit) : 0
        try file.seek(toOffset: offset)
        let data = try file.read(upToCount: byteLimit) ?? Data()
        var lines = data.split(separator: 0x0a, omittingEmptySubsequences: false)
        // Skip an incomplete head/tail while the provider is appending or the read is capped.
        if offset > 0, !lines.isEmpty { lines.removeFirst() }
        if data.last != 0x0a, !lines.isEmpty { lines.removeLast() }
        var titles: [String: String] = [:]
        for line in lines where line.count <= 16_384 {
            guard let entry = try? JSONDecoder().decode(Entry.self, from: Data(line)), sessions.contains(entry.id) else { continue }
            let title = String(entry.thread_name.prefix(200)).unicodeScalars.map {
                CharacterSet.controlCharacters.contains($0) ? " " : String($0)
            }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            // This index is append-only; the last complete entry is the current name.
            if title.isEmpty { titles.removeValue(forKey: entry.id) }
            else { titles[entry.id] = title }
        }
        return titles
    }

    private struct Entry: Decodable { let id: String; let thread_name: String }
}
