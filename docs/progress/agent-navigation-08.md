# Exact Codex task navigation

Previously Cider activated the recorded Codex desktop process without selecting its task. The shared source-opening action now sends `codex://threads/<session-id>` to that running application. This applies to workspace activity actions, compact HUD cards and response peeks.

The route was verified in the installed `/Applications/ChatGPT.app` (bundle ID `com.openai.codex`, build 8109): its copy-link implementation creates this URL and its URL router resolves `threads` links as local conversations. Cider requires a valid session UUID and the Codex desktop origin. Terminal-hosted Codex and Claude sessions retain their recorded source-app activation behavior. PID, bundle ID and launch date checks remain in place; exited sources are not replaced with another session. Successful navigation dismisses the HUD.

Verification on 2026-09-06:

- 26 Swift tests passed, including the exact desktop URL, terminal/other-provider exclusions and malformed session IDs.
- `./script/build_and_run.sh --verify` passed and relaunched the packaged app.
- The user confirmed: “codex is opening chats now.” This is user-confirmed live navigation; the automated UI click check was not completed.

No hook changes or observer reinstall are required. Exact terminal tab/pane selection remains outside this change.
