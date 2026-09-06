# Implementation status

Native implementation authorized by the user and delivered as described in [current evidence](../progress/agent-tracking-06.md). The proposal below records the broader target; live coverage and listed follow-ups remain unverified.

# Agent tracking and the Agents notch tab

Status: proposed, 6 September 2026. Planning only; no hooks installed, settings changed, or agent sessions inspected. This supersedes the older Codex observation recommendation in integrations.md for this workstream.

## Outcome and scope

Observe independently launched Codex and Claude Code sessions on this Mac. Include Claude Code CLI and local sessions in Claude Desktop's Code tab. Ordinary Claude Chat/Cowork, SSH-hosted execution, and cloud runs are separate capabilities, not automatically covered by a local hook.

Add Agents alongside Now Playing, TODO, and Usage in the notch, plus a full Agents workspace page. Track concurrent sessions and child agents without requiring users to launch work from Cider. First version observes and opens the source; it does not send prompts, approve tools, stop agents, or edit their models/permissions/MCP settings. Usage remains account-scoped and separate.

## Source-backed feasibility

- Current [Codex hooks documentation](https://learn.chatgpt.com/docs/hooks) covers session/turn/tool/approval/subagent lifecycle events, Interrupt, and hooks.json or inline configuration. Hooks require review/trust; multiple sources accumulate. Common payloads provide session identity and cwd; some events add turn identity. Transcript format is explicitly unstable. Exit zero with empty output leaves execution unchanged. Installed CLI reports 0.153.4, but actual delivery in its desktop/CLI clients has not been tested.
- [Claude Desktop documentation](https://code.claude.com/docs/en/desktop#shared-configuration) says local Code sessions and CLI share settings and hooks. SSH runs execute on another host and need a separate future bridge. Do not equate the desktop app's ordinary chat surface with Code sessions.
- [Claude hook reference](https://code.claude.com/docs/en/hooks) provides lifecycle, tool, permission, notification and subagent signals. Permission notifications complement direct permission events; execution modes and event coverage differ. Validate the installed version before enabling events.
- [Codex App Server](https://learn.chatgpt.com/docs/app-server) remains an optional future observation source. Local `codex app-server --help` includes daemon and proxy commands, but their presence does not prove safe subscription to every independently running client. Do not resume/fork a thread to watch it.

## Recommended collection strategy

Use two provider configurations pointing to one Cider-bundled native `cider-events` helper. Prefer a dedicated user-level installation per provider so new workspaces are covered. Offer project-only scope as an alternative; avoid installing both scopes for the same provider. Configuration installation needs a concrete diff, preserves unrelated hooks, and has an exact removal path. No external CodexBar install and no MCP server is required for lifecycle tracking.

The helper reads hook stdin, discards prompt/tool arguments/transcript bodies, and retains only allowlisted event metadata. It writes a small durable event into a user-owned spool, then signals Cider over a local Unix socket. Cider ingests atomically and deduplicates before removing acknowledged spool entries. When Cider is closed, bounded retention allows later recovery. Disk errors/drop counts become a connection-health issue; observation must not block the agent.

Use an absolute stable executable path in Application Support, owned by this user, with no shell-profile/PATH dependency. Proposed budgets: helper runtime under 100 ms normally; explicit one-second hook timeout; maximum event 8 KiB after projection; bounded input read/drain and spool size. Return zero with no stdout, no approval decisions, and no injected context. Use async hooks only for events whose provider supports them and after validating ordering. Preserve upstream timestamps/IDs where provided; do not invent reliable sequence ordering from concurrent helper completion order.

Unix socket/spool permissions restrict other users. Validate schema, peer identity where available, and payload sizes. Repo content or a forged session label can never become a command. No credentials, whole transcripts, browser data, or unrestricted process command-line logging.

## Event mapping to validate

| Signal | Cider interpretation |
| --- | --- |
| SessionStart | Register/resume session; Ready until work is observed |
| UserPromptSubmit | Working; new turn when source supplies identity |
| PreToolUse | Working with optional tool-name label; never means approval is required |
| PermissionRequest | Attention candidate; confirm visible pending request where possible because other hooks may decide automatically |
| PostToolUse | Tool returned; clear matching attention only with reliable correlation, otherwise reconcile conservatively |
| Stop | Finished responding / Ready; never marks a feature or TODO verified |
| SessionEnd | Ended session, independent of turn completion |
| SubagentStart / SubagentStop | Add/update a child under the parent; preserve parent state |
| Codex Interrupt | Interrupted turn |
| Claude Notification | Supported permission/input notification types add attention; generic prose is not a state parser |
| Claude PostToolUseFailure / StopFailure, when supported | Record failure evidence with scope; a failed tool is not necessarily a failed agent run |

Inspect exact Claude and Codex event schemas separately; do not share a parser just because event names match. Approval resolution, user questions, interrupted runs, and Stop hooks that continue work require explicit live tests. Missing events must produce uncertain coverage, not fabricated certainty.

## State and identity

Store execution (`ready`, `working`, `interrupted`, `ended`, `unknown`), attention (separate pending items), and connection health (`live`, `stale`, `disconnected`) separately. Persist the last observed state and its timestamp even when connectivity is stale. A quiet reasoning interval must not automatically become Ready or Finished. A process exit without a terminal event becomes Disconnected/Unknown, not Completed.

Canonical identity: host + provider + session ID, plus turn and child IDs when supplied. Cwd and repository/worktree paths are associations, not session identity; two sessions in the same repository remain distinct. PID + process birth time can assist reconciliation but never replace source session IDs. Surface provenance as CLI/Desktop only when established; otherwise show Codex or Claude Code without guessing.

Minimum event: schema version, event ID, provider, host ID, session ID, optional turn/child/parent ID, event type, observed/received time, cwd, optional tool name, source version and confidence. User-authored aliases provide friendly titles without collecting prompts. Keep recent ended sessions separately with a proposed 24-hour retention default; make detailed history opt-in.

## Alternatives and recovery

1. Hooks: primary live signals for newly observed sessions after setup.
2. Bounded process discovery: installation/running-process hints and crash reconciliation; label Recent activity/Detected, not Working or Needs approval.
3. Opt-in bounded history metadata: optional enrichment for sessions predating setup; versioned fallback, never approval truth.
4. App-server/SDK: revisit when a read-only existing-session subscription is proven. A Cider-owned runner would change the product scope.

No full disk crawl, scanning on hover, or repeated spawning of provider CLIs. Reconcile at launch/wake and on relevant process/file events; cached snapshots feed the UI. If periodic fallback is necessary, profile and bound it. Show Restart or resume this agent to finish connecting when hook activation requires it.

## Agents tab and workspace

Tab order proposal: Agents, TODO, Now Playing, Usage. Keep explicit selection stable; new events must not switch tabs, expand/pin the HUD, or steal focus. Use compact labels/icons/tooltips if four tabs do not fit; preserve keyboard access and existing capture-release behavior.

Collapsed notch: a small attention badge and working count, visually distinguished from task count. Expanded Agents tab: summary counts, then at most three rows, attention first. Each row has provider icon, project/user alias, short state, and source age. Expand child-agent detail in the workspace rather than multiplying HUD rows. Footer opens All agents.

Example:

    Agents   TODO   Now Playing   Usage
    2 working · 1 needs you
    Codex         Session engine     Needs approval
    Claude Code   Website            Working · 2 helpers
    Claude Code   Review              Finished responding
                                      All agents ↗

Row action opens the source app/session only if an exact supported route exists; otherwise offer Open app, Reveal workspace, and Copy session ID. No fabricated deep links or UI scraping to approve dialogs. Workspace adds project/provider filters, session tree, event timeline, freshness, and connection health. Notifications are optional, deduplicated per attention item, and acknowledge/snooze does not resolve the underlying provider request.

## Setup experience

Agents → Connect → select Codex and/or Claude Code → show detected versions and proposed hook changes → user enables installation → provider trust/reload step → synthetic self-test plus a real session event → Connected.

Show partial coverage honestly: helper installed is not proof that every event works. Claude Desktop local sessions reuse the Claude connection. Uninstall removes only Cider-owned entries/helper assets, preserving other hooks and user work. Read-only discovery can run before setup; settings modifications remain the final explicit enable step.

## Delivery and acceptance

1. Capability spike: frozen synthetic payload fixtures; verify version/schema support and live event delivery in Codex CLI/Desktop and Claude CLI/Desktop local Code. Establish attention-resolution and child identity behavior. No automatic user config changes during research.
2. Shared ingestion: native helper, bounded durable spool, reducer, dedupe, stale/crash recovery, unit tests. Replay duplicates, out-of-order Stop/new prompt, concurrent children, PID reuse, helper unavailable, disk full and app restart.
3. Connections: installation preview/removal, provider trust steps, version checks, self-test, clear coverage/status. Confirm existing third-party hooks and approvals remain unchanged.
4. Agents workspace and fourth HUD tab: cached shared model, attention ordering, source actions, accessibility and keyboard navigation. No coupling to TODO capture or account quota refresh.
5. Live acceptance: at least two simultaneous sessions per provider, same-cwd distinct sessions, child agents, prompt/approval/continuation/interrupt/normal exit/crash, restart mid-run, screen/Space changes. Verify no false completion and no measurable tool-path delay; test Cider absent. Hardware gate covers switching all four HUD tabs and automatic collapse after capture.

Ready to implement only after the capability spike records supported versions and fixtures. Native implementation was subsequently authorized; installation remains a reviewable app action.
