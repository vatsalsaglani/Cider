import Foundation

/// Cursor's documented hook JSON is normalized before entering Cider's shared reducer.
/// Only the final response preview is retained; no transcript files or tool bodies are read.
enum CursorHookInput {
    static let events = ["sessionStart", "sessionEnd", "beforeSubmitPrompt", "preToolUse", "postToolUse", "postToolUseFailure", "subagentStart", "subagentStop", "afterAgentResponse", "stop"]
    static func normalize(_ input: [String: Any]) throws -> [String: Any] {
        guard let name = input["hook_event_name"] as? String, events.contains(name) else { throw CocoaError(.coderInvalidValue) }
        let mapped: String
        switch name {
        case "sessionStart": mapped = "SessionStart"
        case "sessionEnd": mapped = "SessionEnd"
        case "beforeSubmitPrompt": mapped = "UserPromptSubmit"
        case "preToolUse": mapped = "PreToolUse"
        case "postToolUse": mapped = "PostToolUse"
        case "postToolUseFailure": mapped = "PostToolUseFailure"
        case "subagentStart": mapped = "SubagentStart"
        case "afterAgentResponse": mapped = "AgentResponse"
        case "stop", "subagentStop":
            switch input["status"] as? String {
            case "completed": mapped = name == "stop" ? "Stop" : "SubagentStop"
            case "aborted": mapped = "Interrupt"
            case "error": mapped = "StopFailure"
            default: throw CocoaError(.coderInvalidValue)
            }
        default: throw CocoaError(.coderInvalidValue)
        }
        var result: [String: Any] = ["hook_event_name": mapped]
        result["session_id"] = input["conversation_id"] ?? input["session_id"]
        result["turn_id"] = input["generation_id"]
        result["cwd"] = input["cwd"] ?? (input["workspace_roots"] as? [String])?.first
        result["tool_name"] = input["tool_name"]
        result["tool_use_id"] = input["tool_use_id"]
        if name == "subagentStart" || name == "subagentStop" {
            guard let child = input["agent_id"] as? String, !child.isEmpty else { throw CocoaError(.coderInvalidValue) }
            result["agent_id"] = child
        }
        if name == "afterAgentResponse" { result["last_assistant_message"] = input["text"] }
        return result
    }
}
