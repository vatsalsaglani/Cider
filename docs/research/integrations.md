# Integration strategy and capability limits

Research date: 2026-09-06. No live agent credentials, provider account endpoints, or Jira account were accessed. No hooks or provider settings were changed.

## Contract first

`AgentAdapter` exposes `discover`, `observe`, `readExcerpt`, `openOrigin` and a capability set. `UsageAdapter` exposes account/window snapshots. Optional actions such as replying, sending feedback, or resolving an approval are distinct typed capabilities with exact source identities and result acknowledgements. An available observation source does not grant an action channel.

For the MVP, observe existing independently launched Claude/Codex sessions. Do not replace their orchestration or require all runs to originate in Cider. Distinguish local host from remote host; remote telemetry is a later explicit authenticated bridge, not a guessed local filesystem path.

## Provider matrix

| Provider | Candidate evidence | Limitation and required proof |
| --- | --- | --- |
| Codex | Documented app-server history/status/events and rate-limit method; local generated protocol schema | Live state belongs to the connected server's loaded sessions. Prove observation of desktop/CLI sessions without resuming, forking, or stealing control |
| Claude Code | Opt-in event hooks with session/worktree IDs, notifications and response-stop events | Stop means response ended, not feature verified; missing hooks provide unknown/inferred state |
| Cursor | Source-derived adapter patterns in Codenotch/CodexBar; optional usage source | Provider internals can drift; exact run/approval support is unproven and capability-gated |
| Manual | User-created run and source link | Works offline; clearly labelled manual, no claimed live state |
| Other agents | Versioned adapter extension | Add only after a documented/tested source exists; no universal process-name inference |

## Codex evidence

The installed CLI's `app-server --help` and generated JSON schemas include `thread/list`, `thread/read`, `thread/status/changed`, and `account/rateLimits/read`. Public documentation describes runtime statuses for loaded threads and account-scoped quota windows. `thread/read` supports metadata-only reads and paginated history is preferred. This does not establish access to a different process's live sessions. See [official app-server documentation](https://learn.chatgpt.com/docs/app-server).

Phase 01 must identify a supported connection/subscription path to the server actually owning the user's sessions. Compare two independently running desktop/CLI tasks, a waiting request and an idle task. Do not resume a task merely to observe it. If the installed server offers a daemon/proxy path, inspect its version/auth contract before use. Public API stability and connection permissions are separate gates.

The Codex app tools available to this planning conversation are host capabilities. A shipped Swift app does not automatically receive them. Do not hardcode `mcp__codex_app` calls into Cider or claim this planning task's visibility transfers to the app.

Fallback: bounded opt-in local history metadata with source/version/freshness, explicitly labelled inferred; manual links and copied feedback remain usable. Fallback does not satisfy the live-attention MVP gate. File modification times cannot prove approval or user-input state.

## Claude hook bridge

Use documented events such as `SessionStart`, `UserPromptSubmit`, `Notification`, `PermissionRequest`, `Stop`, `SubagentStart/Stop`, and `SessionEnd` only where supported by the installed version. Noninteractive-mode differences must be tested. The [official guide](https://code.claude.com/docs/en/hooks-guide) explicitly distinguishes response-stop from task completion.

Propose a small native event helper invoked by user-enabled hooks. It forwards allowlisted metadata over a user-owned local socket; if Cider is unavailable, it atomically writes one bounded event file in an app-specific spool. Acknowledge only after durable persistence; dedupe replay by event ID. Timeouts/errors must never block or change the agent's work. Preserve existing user hooks and offer exact install/remove diffs during future setup.

Observe approval requests; do not return automatic allow/deny output from an observation hook. Initial actions open the source session. Interactive responses require a separately verified request/response channel and explicit user action. Do not parse arbitrary prose as executable instructions.

## Quotas and CodexBar

Use native account/window snapshots for Codex where supported. Inspect CodexBar's provider boundary/refresh patterns for Claude/Cursor and optionally support its separately installed JSON CLI through a narrow process adapter after verifying the CLI contract. Do not vendor the entire app or copy credentials/cookie extraction flows by default.

The [reference report](reference-codebases.md) pins CodexBar to `3a676e143e230d4ae71121c8a1e7942cb87b3f7a` and documents bounded scans, timeouts, adaptive refresh, focus-only session actions and MIT license evidence. Authentication paths vary by provider; users choose a supported path in onboarding. Log no tokens, cookies, raw auth errors or response bodies containing credentials.

Usage display must include source and age, exact provider bucket/window, account identifier (redacted label), reset time if known, and unknown/error states. Rate limits are not run-specific costs. Refresh independently from agent polling and keep a last-good cache. Handle expired auth, rate limiting and offline status with backoff and recovery actions.

## Jira rollout

Phase 02 supports a normal issue URL link without authentication. Phase 05 adds read/import of selected assigned issues, followed by deliberate create/update/transition actions. Never mark a Jira issue done merely because the local task box was checked unless the user configured that mapping and the remote transition is available.

For a personal-only build, explicitly configured API-token access may be evaluated; store the token in Keychain and scope requests to the chosen site. For a distributed product, choose a supported authorization architecture. Atlassian's published [3LO flow](https://developer.atlassian.com/cloud/jira/platform/oauth-2-3lo-apps/) includes a client secret; do not embed a shared secret in a desktop binary or assume a public PKCE flow exists. A service-assisted flow or later documented public-client support needs its own decision. [API-token guidance](https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/) is a separate route, not a substitute for a distributable OAuth design.

Use a local transactional outbox for pending mutations, deduplication keys, retry/backoff, and explicit failed/conflict states. Read remote version/status before a destructive overwrite or transition; map transitions by ID from the current issue workflow. Replay is at-least-once, so create operations need reconciliation to prevent duplicate issues after ambiguous responses. Initial imports never send messages or comments.

## Test scope

Use synthetic event streams, historical schema fixtures, a fake clock and local HTTP/process fixtures. Test duplicates, out-of-order terminal events, missed hooks, PID reuse, source truncation/rotation, stale data, reconnect, unknown fields, unauthorized sources, and cancellation. Live tests are separate and list exact supported tool versions. A new adapter stays unavailable until its observation and action capabilities pass their own gates.

