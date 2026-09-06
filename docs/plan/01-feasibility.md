# Phase 01 — retire the hard risks

Status: ready to schedule after the user starts native implementation. These work orders define future work; none is running now.

## Coordinator bootstrap

Read `AGENTS.md`, current progress, architecture, and data/document contracts. Create the native package/bundle and minimal fixture-driven workspace. Follow the available Build macOS Apps `build-run-debug` skill's Run-button bootstrap for `script/build_and_run.sh` and `.codex/environments/environment.toml`. Verify a real `.app` launches, not just a bare Swift executable.

Freeze `Domain` IDs, snapshots, adapter capabilities, document bridge messages, and token accessors in one reviewed base revision. Record exact toolchain, dependency pins and notices. Then create isolated worktrees from that same base if the user authorizes fan-out. Root manifest, shared Domain, generated resources, and integration commits remain coordinator-owned.

## Independent work orders

| ID | Owned paths after scaffold | Contract / result | Acceptance evidence |
| --- | --- | --- | --- |
| P01-A Display | `Sources/CiderPlatform/Display/`, `Panels/`, related tests | Pure geometry plus nonactivating panel, top/left/right/bottom, built-in role, offsets, hover/pin | External-focus and display matrix; transparent-region click-through; no focus theft |
| P01-B Editor | `Sources/CiderPlatform/Editor/`, `Resources/Editor/`, editor fixtures/tests | One lazy Vditor WKWebView, local renderers, versioned bridge, minimal document fixture harness | Offline Mermaid/code; IME/undo; source/frontmatter preservation; memory and hostile-content gates |
| P01-C Observation | `Sources/CiderAdapters/Codex/`, `Claude/`, adapter fixture tests | Capability probe; exact existing-run observation; hook-envelope experiment on fixtures | Record tool versions, two existing sessions, explicit waiting event, reconnect; no resuming/control side effects |
| P01-D Data | `Sources/CiderData/`, `Sources/CiderPlatform/Documents/`, data/file tests | GRDB transaction layer, one document writer, asset journal/conflict handling | Duplicate/out-of-order replay; crash after image write; external-edit collision; recovery after restart |

P01-B uses a fake DocumentSession conforming to the frozen protocol until P01-D integrates. P01-A consumes fixed `HUDSnapshot`s, not providers. P01-C emits events through an injected sink. This keeps lanes independently reviewable.

If slots are limited, run A/B/C first and D next. The initial research task used **Terra High** in a separate Codex task, as requested. Any further task creation follows the user's new implementation instruction and preserves the specified model choice; no in-chat subagent substitution.

## P01-A completion detail

Implement edge geometry with negative display origins and retina scale. Separate persistent display preference from runtime fallback and window focus. Record the physical hardware matrix in [verification](../verification.md). Test hover, click, pin, popover gap, hotkey recovery, screen switch, sleep/wake, and clamshell restoration. Software geometry tests alone cannot close the hardware gate.

## P01-B completion detail

Select a release/revision of Vditor, lock its full asset graph, record transitive notices and any strict-Mermaid patch. Build the fixture described in [editor research](../research/editor-stack.md). Confirm there is one active rich editor, no remote assets, revision-safe save acknowledgements, preserved frontmatter, clean handler teardown and an explicit failed-render state. The browser canvas is not acceptance evidence for this work order.

## P01-C completion detail

Prove the distinction between a server listing stored history and observing another app's current runtime. Capture exact supported transport/subscription and auth setup without storing secrets. Use user-authorized real sessions only for the bounded live check; all reducer/adapter regressions use sanitized synthetic fixtures. If exact existing-session waiting state is unsupported, record **live attention gate blocked**, show the usable manual/inferred fallback, and return the integration decision to the coordinator.

Claude hook installation is a separate explicit setup action after a reviewable diff exists; fixtures do not require changing the user's `.claude` configuration. Observation hooks must exit without approving, blocking, or steering the agent. No live provider quota calls are necessary to prove the event contract.

## P01-D completion detail

Use a temporary fixture workspace. Paste/import duplicate images, force disk-save failure, interrupt between asset and note commits, externally replace the note, move/rename the folder, and reopen. Preserve original assets, drafts, both conflicting versions, and stable IDs. Do not use the user's real notes for destructive failure injection.

## Integration and exit gate

Integrate D's persistence, B's editor bridge, A's HUD and C's explicit observations through the frozen Domain. Execute the acceptance path: imported/manual lane → explicit event → single Inbox item → linked note → pasted local image → save/reopen. Run a release measurement on the representative note.

Phase 01 exits only when the display and editor gates pass, critical persistence tests pass, and existing-session visibility is either proven or its changed scope is explicitly accepted by the user. A beautiful shell cannot hide a failed observation gate.

## Handoff template

```text
Work order and owned paths:
Base revision / final revision:
Behavior delivered:
Checks actually run and evidence paths:
Native / hardware / live-provider checks not run:
Dependencies and notices added:
Deviations or shared contract changes requested:
Next integration step:
```

Do not repair a cross-lane contract ad hoc. Put the proposed change and affected lanes here, let the coordinator update the base, and resume from one shared contract. Keep changes local unless the user asks for publishing.

## Deviations

None during planning. Record deviations beside the affected work order when native work begins.

