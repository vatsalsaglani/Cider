import Foundation
public struct MarkdownParts: Equatable, Sendable {
    public let header: String
    public let body: String
    public init(_ text: String) {
        let newline = text.hasPrefix("---\r\n") ? "\r\n" : "\n"
        let opener = "---" + newline
        if text.hasPrefix(opener), let end = text.range(of: newline + "---" + newline, range: text.index(text.startIndex, offsetBy: opener.count)..<text.endIndex) {
            header = String(text[..<end.upperBound]); body = String(text[end.upperBound...])
        } else { header = ""; body = text }
    }
}
