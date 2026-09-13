# Domain and event contracts

## Implemented linked-work contract

`Sources/CiderDomain/LinkedWork` and schema version 1 in `CiderData/LinkedWork/Schema.sql` define the shipped TODO/chat/note/journal graph. Broader Feature/Phase/Lane concepts below remain proposed. The app owns one SQLite writer at `~/Library/Application Support/Cider/work.sqlite`; Direct CLI database access is read-only and never creates or migrates a database. User-requested CLI writes use a private per-store inbox and live app lease; the running app executes closed task/note commands against its existing repository and refreshes shared UI models. Task edits require their current revision; timeouts have an uncertain outcome and must not be blindly retried. See [CLI commands](../cli.md). Legacy task IDs and descriptions survive one-time import, with a byte-preserving legacy backup.

Journal ingestion commits attribution episodes, source event IDs and entries before the observer ledger/spool acknowledgement. Replays of the same source event are idempotent per task. Distinct hook invocations with new IDs are at-least-once. Identified delayed responses retain the original assignment after detach; directory equality never establishes attribution. Question resolution matches the original chat/link/question, with a bounded historical lookup of 4,096 journal entries per task. A limit failure preserves the spool rather than guessing.

Context is capped at 256 KiB, notes at 64 KiB, today's summary at 20 tasks. Outputs expose revision, truncation and sequence information; unknown data is not fabricated. Graph queries are bounded at 1,000 nodes and 3,000 edges, with one/two-hop local scopes. Deleting a TODO removes its relationships and journal but leaves Markdown bytes and provider identities intact. See [linked-work evidence](../progress/linked-work-14.md).


Status: proposed schema v1; freeze in Phase 01 before implementation fan-out.

## Entities

| Entity | Essential fields |
| --- | --- |
| Workspace | UUID, name, ordered root IDs, preferences |
| FolderRoot | UUID, bookmark/access locator, display name, resolved URL, optional repository ID |
| Feature | UUID, workspace ID, title, outcome, repository IDs, active phase ID |
| Phase | UUID, feature ID, name, sequence, gate definitions, state |
| Lane | UUID, phase ID, title, owned paths, dependencies, plan document IDs |
| AgentRun | UUID, provider/account/host/session/turn IDs, lane associations, parent run ID, worktree ID, execution state |
| Worktree | UUID, repository ID, host ID, path, branch, base/head OIDs, observedAt, missing/dirty state |
| AttentionItem | UUID, run ID, request/event key, kind, reason, seenAt, resolution, snoozedUntil |
| Verification | UUID, lane/run IDs, tested revision, environment, required checks, human outcome, evidence IDs |
| TaskItem | UUID, title, state, dueDate/instant, plannedDay/order, linked entities, optional Jira reference/version |
| NoteReference | UUID, root ID, relative path, revision/hash, associated entities |
| Evidence | UUID, verification ID, note/asset locator, kind, original hash, derived annotation locator |
| UsageSnapshot | provider/account/host/source, windows, observedAt, fetchedAt, freshness, error category |

UUIDs are stable across renames. A provider session is keyed by `(provider, account, host, sessionID)`; process PID is only an observation and includes process-start identity if used. Root/path matches suggest associations; ambiguous matches require user selection. No auto-link solely from branch title.

Task `plannedDay` is a calendar-local day value, distinct from all-day or timed due dates. Unplanned tasks stay in backlog. All three capture surfaces share one idempotent create command and draft identity; calendar/day/HUD projections update after the same commit. See [date and capture semantics](../design/tasks-and-capture.md).

## Independent state dimensions

Execution: `unknown`, `queued`, `running`, `waitingForInput`, `waitingForApproval`, `idle`, `completed`, `failed`, `cancelled`. A completed turn need not mean the user's lane is complete; adapters record granularity (`session`, `turn`, or `run`).

Attention kind: `input`, `approval`, `failure`, `verify`, `information`. Resolution: `unresolved`, `resolved`, `dismissed`. Seen/unseen and snoozed are independent attributes.

Verification: `notStarted`, `inProgress`, `passed`, `failed`, `blocked`, `waived`. Required checks record `pending`, `pass`, `fail`, `blocked`, `skipped`, with source and evidence. An agent's self-reported tests remain labelled `agentReported` until adopted into a human-reviewed gate.

Transport: `connecting`, `connected`, `disconnected`, `unauthorized`, `unsupported`. An offline connector does not force its run to completed or failed. Preserve the last observation and mark it stale.

## Observation envelope

```json
{
  "schemaVersion": 1,
  "eventId": "evt-demo-104",
  "source": {"provider": "codex", "hostId": "local", "adapterVersion": "spike-v1"},
  "sessionId": "session-demo",
  "turnId": "turn-demo-3",
  "sequence": 104,
  "occurredAt": "2026-09-06T09:30:00Z",
  "observedAt": "2026-09-06T09:30:00.120Z",
  "kind": "turnCompleted",
  "confidence": "observed",
  "payload": {"outcome": "completed"}
}
```

This is a Cider contract, not a claim that any provider emits this exact schema. Source sequence can be null. For sources without event IDs use a documented stable digest of source cursor + normalized event content, not receipt time. Distinguish `observed`, `inferred`, and `userEntered` evidence.

An event transaction inserts a unique source key, updates the source cursor, projects state, and creates/deduplicates attention. Duplicate delivery is idempotent. For ordered streams, reject older state transitions within a run while retaining audit evidence. For unordered sources, reconcile from authoritative snapshots; receipt order alone cannot revive terminal runs. A new turn uses a new turn identity.

## Persistence and retention

SQLite tables mirror entity IDs and relationships with foreign keys. Event append and projection update are one transaction. Add indices for unresolved attention, run source identity, feature/phase relation, due/Today tasks, note locator, and usage account/window. Keep schema migrations monotonic; back up before a migration and fail without mutating files if upgrade cannot finish.

Default proposed retention: 30 days of normalized high-frequency observations, durable summaries/requests/verification retained until the user deletes them, latest and recent quota snapshots retained for a configurable short period. Store short relevant reply excerpts only after connector opt-in; raw transcripts load from source on request. Do not copy every token into the database.

## Quota contract

Each window holds `windowId`, provider label, optional model/bucket, `usedPercent?`, `windowDurationSeconds?`, `resetAt?`, optional unit/limit, and observation provenance. Missing values remain null. UI clamps numerical presentation to 0–100 while retaining/reporting anomalous source values for diagnosis. Never average unlike quotas or sum account percentages.

Sparse updates merge only documented present fields. A missing window is not automatically cleared. A full authoritative snapshot may replace its explicitly scoped windows. Estimate freshness per adapter and display elapsed time; do not replace old values with zero on error. Derived remaining is `max(0, min(100, 100 - used))` only when `used` is known.

## Verification invalidation

Gate completion requires all required checks passed, or a recorded human waiver for a named check. Compare tested OID and current OID. A changed OID makes current evidence historical until revalidated; retain the prior result. A manually entered success is visible as such. Never have a reducer infer success from an elapsed timer or a quiet process.
