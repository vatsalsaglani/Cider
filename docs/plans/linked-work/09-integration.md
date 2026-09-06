# Plan 09 — Package and verify the complete linked workflow

Branch: `linked-work/09-integration`. Depends on: 06, 07, 08.
Runs in parallel with: none; coordinator runs locally.

## Goal

Integrate the durable journal, graph and CLI/skill into the actual Cider app, package them together and verify the full linked workflow. Finish with clear native, fixture and live-provider evidence. The shipped result keeps task state, agent activity and user verification distinct.

## Evidence and baseline

The source quotes below were checked at `192b50f0a83c1163009d229026ae1733c3f229a9`. Later numbered dependencies intentionally change some anchors; locate the quoted symbol and compare the merged contract before editing.

- `Features/Agents/AgentTrackingModel.swift:63`: `let ledger = try await AgentIO.run { try AgentEventStore.ingest(root: root) }`. Round B changes this path; verify actual production wiring rather than only testing an isolated JournalIngestor.
- `Features/Agents/AgentTrackingModel.swift:149`: `func openSource(_ row: TrackedSession) {`. Graph/TODO source actions must reuse exact-source routing.
- `Features/Notch/NotchHUDView.swift:60`: `case .agents: AgentsView(model: agents, compact: true)`. Compact views share components with workspace views; adding inspector actions can regress HUD dimensions.
- `script/build_and_run.sh:13`: `pkill -x Cider >/dev/null 2>&1 || true`. Packaging/relaunch is a single coordinator action, never a parallel lane test.

Fresh worktrees contain the committed editor runtime and synthetic fixtures, not the user's Application Support databases, observer spool, build products or installed skills. Never use live data as a test prerequisite. See the [overview](00-overview.md) for the common-base and fixture rules.

## File ownership

Create or edit only these files. Seeded implementation bodies transfer between sequential phases; concurrent ownership never overlaps. The plan's own file is for deviations and handoff evidence.

- `App/CiderApp.swift`
- `App/WorkspaceView.swift`
- `App/LinkedWorkCoordinator.swift`
- `Features/Agents/AgentConnectionsView.swift`
- `Features/Notes/NotesModel.swift`
- `Features/Notch/NotchHUDView.swift`
- `script/build_and_run.sh`
- `script/verify_linked_work.sh`
- `script/verification/LinkedWorkSmoke.swift`
- `Tests/CiderIntegrationTests/LinkedWorkflowTests.swift`
- `docs/product.md`
- `docs/contracts/data.md`
- `docs/contracts/documents.md`
- `docs/architecture.md`
- `docs/implementation/dependencies.md`
- `docs/verification.md`
- `docs/progress/linked-work-14.md`
- `.agents/skills/working-with-cider/references/data.md`
- `docs/plans/linked-work/09-integration.md`

Do not touch: Any unowned or frozen shared files until the coordinator explicitly revises the relevant contract/ownership and reruns dependent gates. Do not modify user hooks, auth stores or unrelated installed skills.

## Context you need

Read the [overview](00-overview.md), this plan and the applicable Cider skill first, then only these routes/symbols:

- Plans 06–08, every Deviation and final handoff, plus the fully merged diff.
- `App/{CiderApp,WorkspaceView,LinkedWorkCoordinator}.swift`: round A composition and route handling.
- `Features/Agents/{AgentTrackingModel,AgentConnectionsView}.swift`, `Features/Notes/NotesModel.swift`, `Features/Notch/NotchHUDView.swift`.
- Merged `JournalIngestor`, `WorkGraphView`, `TodoContextReader`, `AgentAccessView` and CLI/skill README.
- `script/build_and_run.sh`, `script/verify_linked_work.sh`, `script/verification/LinkedWorkSmoke.swift`.
- `docs/{architecture,verification,product}.md`, `docs/contracts/{data,documents}.md`, `docs/implementation/dependencies.md` and `.agents/skills/working-with-cider/references/data.md`: final contract/document updates.

## Precise edits

1. **Journal wiring.** Instantiate JournalIngestor with the same ready repository/host identity as the task UI and inject it before observer refresh starts. Migration failure cannot silently fall back to acknowledging unjournaled linked events. Preserve recovered-event notification suppression, live question peeks, linked attention and usage Stop callbacks.
2. **Graph routing.** Add a workspace Graph destination and View connections from task, note and chat actions. Route exact task/note/chat identities through the scene coordinator and existing save-before-navigation/exact-source activation. Missing files/exited chats show recovery guidance. Confirm graph/backlink agreement after edits and relaunch; no full graph in the notch.
3. **Context and note actions.** Wire the `copyContext` route from TODO detail using TodoContextReader, with note content explicitly chosen. Complete Save checkpoint to note with the preview from 04, source/time/truncation attribution, editor save/hash checks and file-registration recovery. Preserve the one-editor lifecycle if a destination note is already open and dirty.
4. **Agent access/package.** Place AgentAccessView in the Agents setup area. Build `cider-cli` and copy it to `Contents/Helpers/cider` and the portable skill to `Contents/Resources/cider-workflow/`. Also package the new CiderData schema resource bundle and prove resource lookup for both the app and CLI independently of the checkout. Test a staged bundle built in an isolated scratch directory after that scratch build is removed; do not rely on SwiftPM resource accessors falling back to a developer build path. Setup previews the exact project-local integration files and provides uninstall. Keep observer Connect/Disconnect, usage controls and Activity/Agents defaults intact. Existing provider hooks need no reinstall for this plan set.
5. **Whole-flow tests.** Extend the fixture harness and add `LinkedWorkflowTests`: legacy import, two same-workspace chat identities, shared contributor with separate assignment episodes, shared note, duplicate/delayed Stop, pending/resolved question, detach, restart, graph navigation and CLI app-closed parity. Test journal failure/recovery, dirty editor conflict, note rename/missing/relink and task deletion retaining note bytes/provider identities.
6. **Native/live gates.** After offline checks, build/relaunch once locally and inspect workspace/notch on the native app. Use a temporary workspace/TODO and the user's configured Codex plus Claude sessions only for the intended end-to-end test; never auto-send prompts or approve tools. Verify exact returns, brief peeks, attention, durable preview and skill read/summarize behavior when the user invokes it. Separate pending user/provider/hardware checks from passed fixture results.
7. **Docs/closeout.** Update product/data/document/architecture/dependency/verification docs and the data skill route to match the final behavior. Record evidence, migration/rollback procedure, preview/dedupe limitations and outstanding release gates in `docs/progress/linked-work-14.md`. Coordinator updates root progress, product proposal and overview graph. Optional full outputs/agent writes remain separately scoped follow-ups.

## Constraints

Merge/review 06–08 first, then run locally without other app relaunches. No silent contract/schema change or data migration shortcut. No full-output collector, TODO write CLI, hosted sync, graph database, wiki-link compatibility or new provider permissions. Keep black/ember controls and bounds, source data as data, and user review separate from agent Stop.

Follow the overview's Swift isolation, no-secret, no-automatic-hooks, plain local commits and ownership rules. If a frozen surface is insufficient, record `CONTRACT CHANGE NEEDED (not made)` with a concrete proposed signature and affected plans. Never silently widen this lane.

## Verification

Run from this branch's repository root. Tests create only temporary synthetic stores/notes.

```sh
swift build --product Cider
swift build --product cider-cli
swift test
script/verify_editor.sh
script/verify_linked_work.sh --fixtures
python3 script/verification/verify_cider_cli.py --binary "$(swift build --show-bin-path)/cider-cli"
git diff --check
```

Coordinator only, after the commands above: `script/build_and_run.sh --verify`. Inspect native graph keyboard/list parity, Reduce Motion, settled/hidden layout resource use, dirty note navigation, compact notch clipping/collapse and exact-source return. Record machine/build, fixture size and observed timings; an unmeasured idle-performance claim is not a pass. Live Codex/Claude invocation, physical multi-display behavior, signing/notarization and distribution checks are separately reported gates. Do not mark the complete workflow delivered while required end-to-end checks remain unresolved.

## Definition of done

- Integrated native routing, migration, journal recovery, graph/backlinks and CLI saved-data parity pass. The packaged CLI/skill has reviewed setup/removal. Required live flow and accessibility/idle checks have recorded evidence; unperformed release/hardware checks are explicitly distinguished. All lane deviations are reconciled and docs describe the shipped scope.
- All commands above ran successfully; quote any failure and unresolved gate in the handoff.
- Changes stay inside ownership, with every departure recorded below. No implementation stub in this lane is reported as working behavior.
- Make plain local commits, suggested final subject: **Integrate package and verify linked work across Cider**. No push or PR is requested.
- Report base/head commit IDs, changed files, verification, deviations and integration risks. Only the coordinator changes overview statuses.

## Deviations

- User amendment on 2026-09-07: UI acceptance is deferred to the user at the end. Do not block implementation/integration on interactive UI acceptance. Report native interaction, accessibility and physical-display checks as deferred when unperformed; retain all automated, build, package and fixture gates.

## Agent start prompt

> Read `docs/plans/linked-work/00-overview.md` and `docs/plans/linked-work/09-integration.md`, plus `.agents/skills/working-with-cider/SKILL.md`. Implement plan 09 on `linked-work/09-integration`. Run locally as the coordinator; do not create a lane worktree for this plan. Goal: Integrate the durable journal, graph and CLI/skill into the actual Cider app, package them together and verify the full linked workflow. Edit only the files in this plan's File ownership list, including its own Deviations section; keep all frozen contracts and sibling files unchanged. Follow the overview's data, hook, isolation and local-commit rules. Run these verification commands from the repo root: `swift build --product Cider; swift build --product cider-cli; swift test; script/verify_editor.sh; script/verify_linked_work.sh --fixtures; python3 script/verification/verify_cider_cli.py --binary "$(swift build --show-bin-path)/cider-cli"; git diff --check`. Also complete the plan's explicit integration/manual gates when applicable; never claim unrun checks passed. Commit locally without pushing. Finish with what works, base/head IDs, changed files, each verification result, merge risks, and Deviations (or state none).
