# Automatic usage refresh and Claude sign-in recovery

Implemented 2026-09-06 after the user reported stalled refreshes and unavailable Claude quotas despite working hooks and CLI `/usage`.

## Behavior

- The shared app-owned `UsageMonitor` starts at launch, independently of which view is open. Successful refreshes schedule the next check ten minutes later.
- Fresh, newly ingested Stop/SubagentStop events schedule only the corresponding provider after a three-second settling delay. Bursts coalesce, with at most one event-driven request per minute. Events received during a request retain one trailing refresh. Initial replay and events older than a minute do not refresh usage.
- Codex and Claude run independently, at most one request each. Each card displays its own loading indicator. Last successful values remain visible with their original timestamp and a stale-data label if a later request fails. Disabled providers do not fetch.
- Automatic failures back off by ten, twenty, then thirty minutes; manual refresh remains available. Sleep cancels scheduled/in-flight work, and wake resumes the schedule without replaying missed ticks. Cancellation reaches the process runner; generation checks reject results from disabled or changed connections.
- Automatic connection explicitly tries OAuth then CLI; it does not use the helper's browser-cookie discovery mode. Existing default OAuth settings migrate to Automatic, while an explicit old CLI choice is preserved. Raw helper errors are mapped to fixed messages rather than shown or logged.
- The bundled helper's dedicated ClaudeProbe sessions are excluded from agent presentation/notifications and usage triggers, preventing background probe activity from producing refresh loops.

## Claude diagnosis

The inherited process environment enabled `CLAUDE_CODE_USE_BEDROCK`. A bounded `claude auth status` query reported third-party/Bedrock; removing inherited routing only for a second probe reported the existing Claude Max sign-in. No credential file or Keychain item was opened for inspection. The user also confirmed `/usage` works in their signed-in terminal.

Cider now excludes Bedrock, Vertex, Foundry, custom Anthropic endpoint/key and transient OAuth overrides from its Claude subscription-usage subprocess environment. It preserves the selected Claude configuration directory, and does not alter terminal configuration, hooks or provider settings. These are Claude subscription quotas, not AWS/Vertex/Foundry spending.

The pinned bundled CodexBarCLI v0.56.6 supports OAuth and CLI sources independently. Its [Claude provider documentation](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/claude.md) describes the credential-access distinction and the dedicated, tool-disabled `/usage` probe. Cider keeps this helper bundled; no separate installation is required.

## Verification

- `swift test`: 33 tests passed. Added coverage for the ten-minute schedule, event coalescing/cooldown, stops during requests, failure backoff, old/duplicate event exclusion, source fallback, sanitized errors, provider routing isolation, independent loading, retained values, disabled-provider late results and process cancellation.
- `./script/build_and_run.sh --verify`: packaged and relaunched Cider successfully.
- Live helper checks: Codex OAuth returned a weekly window; the isolated Claude CLI probe returned session and weekly percentages in about nineteen seconds.
- Live rebuilt app: CUA observed both providers' quota windows and update timestamps, correct connection labels, an enabled refresh button and no loading indicators after completion.
- Ten-minute timing and Stop-triggered refresh were exercised with deterministic time/event tests. A ten-minute physical wait and sleep/wake hardware cycle were not performed.

Changed paths: `Sources/CiderDomain/{ProviderUsage,UsageRefreshSchedule}.swift`, `Sources/CiderData/UsageMonitor.swift`, `Sources/CiderData/Process/{UsageClient,CommandRunner}.swift`, `Features/Usage/`, `Features/Notch/NotchUsageView.swift`, `Features/Agents/AgentTrackingModel.swift`, `App/CiderApp.swift`, and `Tests/CiderDomainTests/UsageRefreshTests.swift`.
