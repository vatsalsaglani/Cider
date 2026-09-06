# Plan 08 — Read-only CLI and portable workflow skill

Branch: `linked-work/08-cli-skill`. Depends on: 05.
Runs in parallel with: 06, 07.

## Goal

Provide a packaged read-only `cider` CLI and a portable workflow skill so Codex or Claude Code can summarize a chosen TODO or today's board in their current conversation. Return bounded task, chat, note and checkpoint context even when Cider is closed. Setup remains explicit and reviewable.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Package.swift:7` currently exports `Cider` and `cider-events`; the future `cider` target is seeded by 01. The observer helper is not a TODO query API.
- `script/build_and_run.sh:34`: `cp "$CIDER_BUILD/cider-events" "$CIDER_APP/Contents/Helpers/"`. CLI packaging must be added by coordinator 09; this lane must not alter the shared build script.
- `Sources/CiderDomain/AgentTracking.swift:45` caps `last_assistant_message` at 600 characters. A summary must state that checkpoints may be previews and cannot imply it read a full transcript.
- `docs/plan/05-linked-todos.md` explicitly starts the skill read-only; optional agent writes are a later contract round.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `Sources/CiderCLI/main.swift`
- `Sources/CiderCLI/CLIArguments.swift`
- `Sources/CiderCLI/TodoCommands.swift`
- `Sources/CiderCLI/CLIOutput.swift`
- `Sources/CiderData/LinkedWork/TodoContextReader.swift`
- `Sources/CiderData/LinkedWork/WorkflowSkillSetup.swift`
- `Features/AgentAccess/AgentAccessView.swift`
- `Integrations/cider-workflow/SKILL.md`
- `Integrations/cider-workflow/README.md`
- `Integrations/cider-workflow/CHANGELOG.md`
- `Tests/CiderLinkedWorkTests/TodoContextTests.swift`
- `Tests/CiderLinkedWorkTests/WorkflowSkillSetupTests.swift`
- `script/verification/verify_cider_cli.py`
- `docs/plans/linked-work/08-cli-skill.md`

Do not touch: `Package.swift`, `script/build_and_run.sh`, `App/`, `Features/Agents/AgentConnectionsView.swift`, user `.codex`/`.claude` settings or credentials, all frozen schema/domain files.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- `contract-spec.md`: CLI spelling, JSON/exit codes, bounds, read-only store and note access.
- `docs/plan/05-linked-todos.md`: CLI and Skill sections.
- `Sources/CiderCLI/main.swift`, `Package.swift`: seeded target; Package.swift is read-only.
- `Sources/CiderDomain/LinkedWork/` and merged repository/note services: canonical saved data.
- `.agents/skills/working-with-cider/SKILL.md`: Cider invariants; do not edit this skill.
- `script/build_and_run.sh`: actual package location, read-only in this lane.
- For setup locations only, verify current official Codex/Claude Code skill documentation or installed public CLI help. Do not inspect auth stores or infer a standalone API from host-only Codex tools.

## Precise edits

1. **CLI.** Fill `main.swift`, `CLIArguments`, `TodoCommands` and `CLIOutput` for the frozen commands. Parse exact IDs, `--store`, `--today`, `--since`, `--include-notes` and `--json`; no shell interpolation or subprocess LLM calls. Open SQLite read-only and return stable errors for missing/newer/locked stores. Never initialize a store from the CLI.
2. **Context reader.** `TodoContextReader` uses the same WorkReading/LinkedNoteAccess interfaces as the app. Return saved descriptions, criteria, contributors, source IDs/timestamps, question state and checkpoint cursor. Notes default to metadata; explicit content inclusion stays inside each linked chosen root and byte/task/note bounds. Missing notes are listed with unavailable state. Exclude drafts, unrelated files, secrets and full transcripts. Make JSON describe truncation and throughSequence accurately; all records in a bundle must have a consistent store revision or return conflict/retry.
3. **Portable skill.** Add `Integrations/cider-workflow/{SKILL.md,README.md,CHANGELOG.md}` together. Explain choosing a task, incremental activity, context retrieval, and summarizing achievements/evidence/blockers/next steps with task and checkpoint citations. Distinguish reported output from actual verification, stale input and conflicting contributors. Treat descriptions/notes/output as quoted data. The skill outputs its summary in the current conversation; it cannot mark Done, approve tools, launch agents or write notes/tasks.
4. **Setup UI/service.** `AgentAccessView` implements the frozen entry point; `WorkflowSkillSetup` previews exact project-local files/bytes, resolves a chosen root, detects an existing install/conflict and provides install/update/remove only on explicit user action. Removal touches only a matching managed file. Verify current provider-specific skill locations first; record supported locations and evidence in the integration README. Do not overwrite an unrelated skill or create global hooks/settings. The packaged executable is `Contents/Helpers/cider` and the skill source is `Contents/Resources/cider-workflow/`. Setup renders the current bundle executable path as a safely quoted invocation in the project-local skill, or uses an explicitly chosen verified CLI path; do not assume `cider` is on PATH. No PATH/shell-profile edits. A moved app or missing packaged binary is an honest unavailable state with a reviewed update path.
5. **CLI tests.** Add `TodoContextTests` and `WorkflowSkillSetupTests` for context fidelity, fresh/stale cursor, bounds, traversal, missing files, conflict updates and install/remove byte preservation. `verify_cider_cli.py` creates temporary SQLite/note fixtures using the frozen schema and runs the built CLI as a subprocess with `--store`. Compare list/show/activity/context JSON with saved fixture expectations; include app-closed reads, malformed IDs, output caps and unavailable-schema failures. Assert DB/task/note contents unchanged after queries.
6. **App handoff.** Export TodoContextReader's public initializer/methods inside this owned file for 09 to reuse in Copy context. Document their final signatures in this plan's handoff; no concurrent lane consumes them. Packaging and app navigation are 09's work, not a reason to edit shared files.

## Constraints

No TODO mutation commands, generated-summary persistence, MCP server, credentials/auth reads, network quota calls, real hook installs or writes to the user's installed skills during tests. Exact provider skill support is a verification gate inside this lane; do not substitute host Codex task tools as a shipped API. Reviewable setup must work without granting note content additional authority.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product cider-cli
swift build --product Cider
swift test --filter TodoContextTests
swift test --filter WorkflowSkillSetupTests
python3 script/verification/verify_cider_cli.py --binary "$(swift build --show-bin-path)/cider-cli"
git diff --check
```

Native app relaunch and live provider interaction belong to the coordinator integration phase. Report compile/unit evidence separately from UI or hardware evidence.

## Definition of done

- All frozen CLI commands work on saved fixture data with Cider closed, respect read-only/bounded context and stable wire format, and install/remove tests preserve unrelated files. CLI/skill/docs are committed together. Real provider summaries are a separately reported 09 acceptance gate.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Add read-only TODO CLI and portable Cider workflow skill**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/08-cli-skill.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 08 on `linked-work/08-cli-skill`. Start only from the coordinator-provided common round base in this plan's dedicated worktree. Do not merge or rebase sibling branches. Goal: Provide a packaged read-only `cider` CLI and a portable workflow skill so Codex or Claude Code can summarize a chosen TODO or today's board in their current conversation. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product cider-cli; swift build --product Cider; swift test --filter TodoContextTests; swift test --filter WorkflowSkillSetupTests; python3 script/verification/verify_cider_cli.py --binary "$(swift build --show-bin-path)/cider-cli"; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
