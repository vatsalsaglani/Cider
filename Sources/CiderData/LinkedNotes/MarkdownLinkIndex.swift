import CryptoKit
import Foundation
import CiderDomain

/// A deliberately small Markdown-link parser: ordinary links only, never wiki links or remote URLs.
public enum MarkdownLinkIndex {
    public static func links(in markdown: String, source: NoteReference, knownNotes: [NoteReference], rootID: UUID) throws -> [NoteDocumentLink] {
        guard source.rootID == rootID else { throw WorkStoreError.invalidInput }
        let candidates = knownNotes.filter { $0.rootID == rootID && $0.available }
        let targets = Dictionary(uniqueKeysWithValues: candidates.map { (normalized($0.relativePath), $0) })
        var references: [String: String] = [:]
        var prose: [String] = []
        var inFence = false

        for line in markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let text = String(line)
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("```") || text.trimmingCharacters(in: .whitespaces).hasPrefix("~~~") {
                inFence.toggle(); continue
            }
            guard !inFence else { continue }
            if let definition = referenceDefinition(text) {
                references[normalizeLabel(definition.label)] = definition.destination
            } else {
                prose.append(maskInlineCode(text))
            }
        }

        var pairs = Set<LinkKey>()
        for line in prose {
            for destination in inlineDestinations(line) + referenceDestinations(line, definitions: references) {
                guard let resolved = resolve(destination, sourcePath: source.relativePath), let target = targets[resolved.path] else { continue }
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
        destinations += matches(shortcut, in: line).compactMap { definitions[normalizeLabel(capture($0, 1, in: line) ?? "")] }
        return destinations
    }

    private static func resolve(_ rawDestination: String, sourcePath: String) -> (path: String, fragment: String?)? {
        let decoded = rawDestination.removingPercentEncoding ?? rawDestination
        guard !decoded.isEmpty, !decoded.hasPrefix("/"), !decoded.hasPrefix("//"), URLComponents(string: decoded)?.scheme == nil else { return nil }
        let split = decoded.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let linkPath = String(split[0])
        guard !linkPath.isEmpty else { return nil }
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
        var masked = "", quoted = false
        for scalar in line.unicodeScalars {
            if scalar == "`" { quoted.toggle(); masked.unicodeScalars.append(scalar) }
            else { masked.unicodeScalars.append(quoted ? " " : scalar) }
        }
        return masked
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
