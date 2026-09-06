import Foundation
import Testing
@testable import CiderDomain

@Test func previewsRenderMarkdownWithoutActions() {
    let rendered = ResponsePreview.render("## Result\n- **Done** and `code`\n[More](https://example.com)\n```swift\nlet x = 1\n```")
    #expect(String(rendered.characters) == "Result\n• Done and code\nMore\nlet x = 1")
    #expect(rendered.runs.allSatisfy { $0.link == nil })
    #expect(rendered.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
}
@Test func excerptsPreserveNewlines() throws {
    let data = try JSONSerialization.data(withJSONObject: ["session_id":"test", "hook_event_name":"Stop", "last_assistant_message":"Result:\n- Done"])
    #expect(try AgentEvent(provider: .codex, payload: data).lastMessage == "Result:\n- Done")
}
