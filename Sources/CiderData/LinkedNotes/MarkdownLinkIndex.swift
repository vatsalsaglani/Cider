import CryptoKit
import Foundation
import CiderDomain

/// A deliberately small Markdown-link parser: ordinary links only, never wiki links or remote URLs.
public enum MarkdownLinkIndex {
    public static func links(in markdown: String, source: NoteReference, knownNotes: [NoteReference], rootID: UUID) throws -> [NoteDocumentLink] {
        guard source.rootID == rootID else { throw WorkStoreError.invalidInput }
        let candidates = knownNotes.filter { $0.rootID == rootID && $0.available }
        let targets = Dictionary(grouping: candidates, by: { normalized($0.relativePath) })
        var references: [String: String] = [:]
        var prose: [String] = []
        var fence: FenceDelimiter?

        for line in markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let text = String(line)
            if let delimiter = fenceDelimiter(in: text) {
                if let openFence = fence {
                    if openFence.matchesClosing(delimiter) { fence = nil }
                    continue
                }
                fence = delimiter
                continue
            }
            guard fence == nil else { continue }
            if let definition = referenceDefinition(text) {
                references[normalizeLabel(definition.label)] = definition.destination
            } else {
                prose.append(maskInlineCode(text))
            }
        }

        var pairs = Set<LinkKey>()
        for line in prose {
            for destination in inlineDestinations(line) + referenceDestinations(line, definitions: references) {
                guard let resolved = resolve(destination, sourcePath: source.relativePath), let matches = targets[resolved.path] else { continue }
                guard matches.count == 1, let target = matches.first else { throw WorkStoreError.conflict }
                pairs.insert(LinkKey(targetID: target.id, fragment: resolved.fragment))
            }
        }
        return pairs.map { key in
            NoteDocumentLink(id: edgeID(source: source.id, target: key.targetID, fragment: key.fragment), sourceID: source.id, targetID: key.targetID, fragment: key.fragment)
        }.sorted { lhs, rhs in lhs.id.uuidString < rhs.id.uuidString }
    }

    private static func referenceDefinition(_ line: String) -> (label: String, destination: String)? {
        let pattern = #"^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>]+)>|(\S+))"#
        guard let match = firstMatch(pattern, in: line), let label = capture(match, 1, in: line) else { return nil }
        return (label, capture(match, 2, in: line) ?? capture(match, 3, in: line) ?? "")
    }

    private static func inlineDestinations(_ line: String) -> [String] {
        let pattern = #"(?<![!\\])\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s\)]+))(?:\s+[^\)]*)?\)"#
        return matches(pattern, in: line).compactMap { capture($0, 1, in: line) ?? capture($0, 2, in: line) }
    }

    private static func referenceDestinations(_ line: String, definitions: [String: String]) -> [String] {
        let pattern = #"(?<![!\\])\[([^\]]+)\]\[([^\]]*)\]"#
        var destinations = matches(pattern, in: line).compactMap { match -> String? in
            guard let label = capture(match, 1, in: line) else { return nil }
            let reference = capture(match, 2, in: line).flatMap { $0.isEmpty ? label : $0 } ?? label
            return definitions[normalizeLabel(reference)]
        }
        let shortcut = #"(?<![!\\])\[([^\]]+)\](?![\[(])"#
        destinations += matches(shortcut, in: line).compactMap { match in
            let preceding = match.range.location > 0 ? (line as NSString).substring(with: NSRange(location: match.range.location - 1, length: 1)) : ""
            guard preceding != "!", preceding != "]" else { return nil }
            return definitions[normalizeLabel(capture(match, 1, in: line) ?? "")]
        }
        return destinations
    }

    private static func resolve(_ rawDestination: String, sourcePath: String) -> (path: String, fragment: String?)? {
        let split = rawDestination.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let linkPath = (String(split[0]).removingPercentEncoding ?? String(split[0]))
        guard !linkPath.isEmpty, !linkPath.hasPrefix("/"), !linkPath.hasPrefix("//"), URLComponents(string: linkPath)?.scheme == nil else { return nil }
        let fragment = split.count == 2 ? String(split[1]).removingPercentEncoding ?? String(split[1]) : nil
        let base = sourcePath.split(separator: "/").dropLast().map(String.init)
        var components = base
        for component in linkPath.split(separator: "/", omittingEmptySubsequences: false) {
            switch component {
            case "", ".": continue
            case "..": guard !components.isEmpty else { return nil }; components.removeLast()
            default: components.append(String(component))
            }
        }
        guard !components.isEmpty else { return nil }
        return (components.joined(separator: "/"), fragment?.isEmpty == true ? nil : fragment)
    }

    private static func normalized(_ path: String) -> String { path.replacingOccurrences(of: "\\", with: "/").precomposedStringWithCanonicalMapping }
    private static func normalizeLabel(_ label: String) -> String { label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    private static func maskInlineCode(_ line: String) -> String {
        var characters = Array(line)
        var index = 0
        while index < characters.count {
            guard characters[index] == "`" else { index += 1; continue }
            let delimiterLength = runLength(of: "`", in: characters, at: index)
            var candidate = index + delimiterLength
            var closing: Int?
            while candidate < characters.count {
                if characters[candidate] == "`", runLength(of: "`", in: characters, at: candidate) == delimiterLength { closing = candidate; break }
                candidate += 1
            }
            guard let closing else { index += delimiterLength; continue }
            for offset in index..<(closing + delimiterLength) { characters[offset] = " " }
            index = closing + delimiterLength
        }
        return String(characters)
    }

    private static func fenceDelimiter(in line: String) -> FenceDelimiter? {
        let characters = Array(line.drop(while: \.isWhitespace))
        guard let marker = characters.first, marker == "`" || marker == "~" else { return nil }
        let count = runLength(of: marker, in: characters, at: 0)
        return count >= 3 ? FenceDelimiter(marker: marker, count: count) : nil
    }

    private static func runLength(of character: Character, in characters: [Character], at index: Int) -> Int {
        var cursor = index
        while cursor < characters.count, characters[cursor] == character { cursor += 1 }
        return cursor - index
    }

    private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern)).map { $0.matches(in: text, range: NSRange(text.startIndex..., in: text)) } ?? []
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func edgeID(source: UUID, target: UUID, fragment: String?) -> UUID {
        let input = source.uuidString.lowercased() + "|" + target.uuidString.lowercased() + "|" + (fragment ?? "")
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

private struct LinkKey: Hashable {
    let targetID: UUID
    let fragment: String?
}

private struct FenceDelimiter {
    let marker: Character
    let count: Int
    func matchesClosing(_ candidate: FenceDelimiter) -> Bool { marker == candidate.marker && candidate.count >= count }
}
