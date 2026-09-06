import Foundation

/// Compact native Markdown for response excerpts; never loads images or follows links.
public enum ResponsePreview {
    public static func render(_ source: String) -> AttributedString {
        var result = AttributedString()
        var inCode = false
        for raw in source.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inCode.toggle(); continue }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" { continue }
            var line = raw
            if !inCode {
                line = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^\s*>\s?"#, with: "", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^\s*[-*+]\s+\[[ xX]\]\s*"#, with: "• ", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "• ", options: .regularExpression)
                line = line.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            }
            var rendered = inCode ? AttributedString(line) : ((try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible))) ?? AttributedString(line))
            // Previews display link labels, with no externally actionable destinations.
            for run in rendered.runs where run.link != nil { rendered[run.range].link = nil }
            if inCode { rendered.inlinePresentationIntent = .code }
            if !result.characters.isEmpty { result.append(AttributedString("\n")) }
            result.append(rendered)
        }
        return result
    }
}
