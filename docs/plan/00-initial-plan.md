# Cider — initial plan

Status: proposed product blueprint, 2026-09-06. Working name, not a cleared commercial brand.

## The outcome

Make three things immediately visible: **what needs my attention, what I intend to finish today, and what I learned while testing**. Connect these to the exact feature, phase, agent run, worktree, and evidence. Keep the notch useful in seconds; open the workspace for sustained work.

## Scope of this phase

Research the referenced repositories and editor packages; define workflows, modules, data and concurrency contracts, design tokens, display policies, phased work orders, and verification gates; create concept artwork and an interactive canvas; establish `AGENTS.md` and a progressive project skill. Do not implement the production app in this phase.

The user supplied 25 visual references. Adopt black notch geometry, compact usage rings, calm desktop hierarchy, image-rich notes, and warm orange accents. Reference screenshots do not add games, music playback, chat bots, billing dashboards, or voice recording to scope.

## Proposed decisions

| Area | Decision | Why / gate |
| --- | --- | --- |
| Platform | macOS 26+, Apple Silicon first; Swift 6 language mode on verified Swift 6.3/Xcode 26.4 | Fits the user's installed Mac and modern SwiftUI; confirm minimum OS before distribution |
| Main app | SwiftUI scenes, navigation, settings, inspectors, commands, Observation | Native desktop behavior and narrow state ownership |
| HUD | One owned AppKit `NSPanel` hosting SwiftUI | Explicit nonactivating hover and stable display geometry |
| Editor | Accepted: one lazy Vditor editor hosted in WebKit | User chose SwiftUI plus one lazy WebKit editor on 2026-09-06; built-in Mermaid, highlighting and live editing |
| Native alternative | TextKit 2 via SwiftMarkdownEngine, custom Mermaid rendering | Better native text behavior; fails the out-of-box Mermaid requirement without additional work |
| Storage | Files for notes/assets/manifests; SQLite/GRDB for local app metadata | Portable notes, transactional event and task state, rebuildable search |
| Agent model | Observe existing tools first; capability-gated actions later | Fits existing Claude planning and Codex worktree execution |
| Display | Built-in display by default, with an independently configured edge/offset | External keyboard focus must not relocate the laptop HUD |
| Usage | Account/window-specific quota observations, separate from run token/cost estimates | Avoid misleading combined percentages |
| Jira | Links and import first; deliberate sync later | Daily tasks remain useful offline; auth model needs its own decision |
| Visual language | Black, warm neutral text, ember-to-amber accent | Explicit user palette; no Qyrus colors |

See [editor evidence](../research/editor-stack.md), [integration capabilities](../research/integrations.md), and [repository comparison](../research/reference-codebases.md). Proposed choices are not claims of a working integration.

## Product surfaces

1. **Collapsed notch:** count of unresolved attention, quiet activity, optional pinned usage. Camera exclusion stays empty.
2. **Expanded HUD:** Inbox, Today, Notes capture, Usage. Max three priority items before opening the workspace. Hover never grabs keyboard focus.
3. **Workspace:** Inbox, Features, Today with date navigation/list/calendar, Notes, Usage; multi-folder source list; contextual inspector. Shared quick task/note actions use icons with tooltips.
4. **Review flow:** finished run → verification checklist → image/text evidence → feedback tied to the run → retest → verified.
5. **Settings:** display anchor/edge/offset, hover behavior, capture shortcuts, workspaces, assets, integrations, notifications, retention, appearance.

The user's visual review added direct task entry in the notch, a reusable task composer across surfaces, a warmer gradient inside the app, native transparency/Liquid Glass, and product copy free of framework/storage terms. These are native requirements, detailed in [task interactions](../design/tasks-and-capture.md) and [materials](../design/materials.md).

## Phases and gates

| Phase | Result | Can proceed when |
| --- | --- | --- |
| 00 · Blueprint | This plan, research, tokens, concept, canvas, working guide | Deliverables checked and decisions visible |
| 01 · Feasibility | Native shell plus isolated display, editor, connector, storage spikes | Pass critical editor/display/session-observation gates; choose editor path |
| 02 · Local daily loop | Real notes/assets, Today, manual feature/phase/run mapping | Reliable save/reopen/conflicts and keyboard workflows |
| 03 · Agent attention | Claude and Codex observation, requests, completion/verification queues | Existing independent sessions demonstrably observed; reconnect and stale behavior correct |
| 04 · Review and handoff | Screenshot annotation, test evidence, feedback bundles, plan import | No loss of originals, exact run/revision linkage, deliberate handoff |
| 05 · Usage and Jira | Codex/Claude/Cursor usage and optional Jira synchronization | Provider/auth contracts verified, offline/outbox/conflict behavior proven |
| 06 · Hardening | Energy, accessibility, durability, signing/notarization, installer | Release checklist and hardware matrix pass |

Phase 01 has concrete [work orders](01-feasibility.md); later phases have [owned lanes and acceptance](02-delivery.md). The sequence prioritizes the editor and actual agent visibility before ornamental HUD features.

## MVP acceptance scenario

Open three workspace folders. Map three features, each with a phase and multiple lanes, to existing Claude/Codex sessions and worktrees. Switch keyboard focus to an external display: the laptop HUD stays attached. An agent asks for input; it appears once in Inbox with source and freshness. Another run finishes; it awaits testing rather than marking the feature done. Open its plan and worktree, record a check, paste a screenshot into a Markdown note, annotate it, add a Mermaid diagram and a code block, and reopen the plain file outside Cider. Turn one finding into a task and prepare a feedback bundle for the originating run. Relaunch: mappings, tasks, and evidence persist. A disconnected provider shows stale/unknown usage. No accounts are needed for the local notes/task loop.

## Risks that shape implementation

- **Editor quality:** source preservation, IME/undo, frontmatter, large documents, and VoiceOver are feasibility gates, not polish tasks.
- **Cross-application observation:** a newly launched agent server may see history without seeing live runtime state owned by another process. Never infer support from a method name alone.
- **Provider drift:** CLI output and private web endpoints may change. Version adapters, retain last-good timestamps, offer manual linkage, and disable unsupported actions.
- **Physical display behavior:** a closed/sleeping laptop screen cannot show pixels. Persist the built-in preference and use the configured fallback until it returns.
- **Resource use:** measure the app and its WebKit/child processes together. A small Swift shell can still host an expensive editor or polling loop.

## Initial skill and dependency policy

Already available: Build macOS Apps (patterns, AppKit, windows, Liquid Glass; build/run and profiling when implementing), imagegen, skill-creator, and visualization. Add only the repository-local `working-with-cider` skill now. No third-party agent skill or app installation is required.

Candidate implementation packages: GRDB, Vditor and its bundled renderer assets, Yams if a native YAML parser is needed, and a small process wrapper after evaluation. Freeze exact revisions and transitive license notices in Phase 01. The canvas does not establish production dependency pins.

## Decisions to revisit

- Editor direction is resolved: SwiftUI plus one lazy WebKit editor. Exact package pin and bridge behavior still need the Phase 01 spike.
- Personal-only distribution versus a supported public product; this affects Jira authorization and packaging, not the basic local workflow.
- Optional remote-agent transport after local observation works. No central orchestration server is required for the MVP.

## Definition of done for Phase 00

Research has source/commit evidence; every requested workflow has a specification; tokens map to SwiftUI components; actor/file/adapter boundaries are explicit; feasibility work orders are actionable; the concept and canvas show the same visual direction; prototype controls and document links are checked; current progress states exactly what has and has not been tested.
