# Question attention and notch peeks

Implemented 6 September 2026.

## Behavior

- Codex `request_user_input_async` and `request_user_input`, and Claude Code `AskUserQuestion`, produce question attention from their existing PreToolUse hooks.
- A new unanswered question triggers the existing five-second gradient peek, with the question text and a click action returning to its source task/app. The HUD does not fully expand or take focus. If already expanded, the question appears directly in Agents.
- “Asking a question” and the question excerpt remain in agent activity after the peek closes, including while an asynchronous agent continues working or finishes responding. Pending questions retain attention beyond the ordinary five-minute last-seen threshold.
- A completion notice cannot replace an active question peek. Question excerpts also appear in recent activity; Markdown uses the existing inert native preview renderer.
- Async PostToolUse is a delivery acknowledgment, not an answer. Codex's structured UserPromptSubmit reply resolves the specific call ID/question index. Synchronous question tool returns resolve only their own call. A new ordinary prompt supersedes outstanding questions; SessionEnd removes them. Existing session reloads retain them. The normal 24-hour ledger retention still applies.

## Data boundary

Only known question tools are inspected. Up to three question texts, 600 characters total per request, are stored; options and other tool input are discarded. Reply parsing keeps only question identities, never answers or copied question text. The event input limit (1 MiB), output limit (8 KiB), one-second helper deadline, local spool permissions and bounded history are unchanged. Optional new event/session fields preserve old ledger decoding. Onboarding disclosure now includes question excerpts.

No hook events or commands were added. The installed helper was an older Cider build, so its executable identity and behavior were checked using an isolated synthetic spool before an atomic upgrade. The prior helper was retained at `~/Library/Application Support/Cider/Helpers/cider-events.previous`. Hook configuration and trust settings were unchanged.

## Verification

- `swift test`: all 40 tests passed. Added coverage includes immediate async acknowledgment, continued tools/Stop, independent question resolution, answer privacy, both blocking tool schemas, bounds/allowlist, restart/old-ledger compatibility, replay suppression and question-peek priority without full expansion.
- `script/build_and_run.sh --verify`: native app/helper built, signed and relaunched successfully.
- Isolated helper check: question request serialized with its call/index identity, no unrelated prompt/options, no stdout/stderr, and a 0600 spool file.
- Live Codex: the actual verification question produced one pending question via PreToolUse. The user confirmed that the brief peek and question appeared. The subsequent UserPromptSubmit reply contained the matching identity and reduced the session's pending count to zero.
- Claude Code question handling is verified with schema fixtures; a live Claude question/answer cycle was not run in this pass.

The Codex [hook reference](https://learn.chatgpt.com/docs/hooks) documents the PreToolUse/PostToolUse inputs. Installed-app observation additionally confirmed hooks around `request_user_input_async`, and the live reply verified its correlation identity. Hookless/hosted tools are not inferred from assistant prose or transcript scanning.

## Changed surfaces

Domain question extraction/reducer/notice selection; shared agent activity model and cards; app-to-notch notice wiring; peek priority; domain/platform tests; progress documentation. No TODO, editor, usage or provider configuration behavior changed.
