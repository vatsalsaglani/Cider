import Foundation
import Testing
@testable import CiderDomain

@Test func desktopTaskDestinationIsExactAndDoesNotCaptureTerminalSessions() {
    let id = "01a07310-b100-4000-8000-123456789012"
    let desktop = AgentOrigin(bundleID: "com.openai.codex", processID: 1, launched: .now, name: "ChatGPT")
    #expect(AgentDestination.taskURL(provider: .codex, session: id, origin: desktop)?.absoluteString == "codex://threads/" + id)
    let terminal = AgentOrigin(bundleID: "com.mitchellh.ghostty", processID: 2, launched: .now, name: "Ghostty")
    #expect(AgentDestination.taskURL(provider: .codex, session: id, origin: terminal) == nil)
    #expect(AgentDestination.taskURL(provider: .claude, session: id, origin: desktop) == nil)
    #expect(AgentDestination.taskURL(provider: .codex, session: "new?prompt=unexpected", origin: desktop) == nil)
}
