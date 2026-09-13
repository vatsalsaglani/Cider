# Current progress

**Cider app identity:** bundle identifier is now `app.cider.desktop`. A one-time startup migration copies legacy `app.cinder.desktop` preferences before model initialization, preserves newer values and retains the old domain. Migration regression test, native build/relaunch and strict signature validation passed; saved workspace folders were verified in the new preferences domain. Computer-use app inventory may retain the old identifier until refreshed.

**Notes restoration:** verified the reported missing notes remained on disk and all five Cider files appeared after expanding the folder. Workspace roots now expand by default on first use; folder expansion, note tabs and active note persist across relaunch. A native model regression test passed for restart restoration. Existing note content is unchanged.

**Document-first task design:** implemented the selected design study with one editable title, compact metadata, content-sized description, criteria and clickable linked-note rows in a 720-point column. Chats/activity disclose inline, Save appears for edits, and linked notes show a parent-task breadcrumb. All 158 Swift tests passed; native build/relaunch, visual inspection, task → note → Back/Forward, breadcrumb return and unsaved-title retention were verified in an isolated native fixture workspace. See [design and checks](task-document-19.md).

**Inline task pages and workspace history:** task details now occupy the main workspace with open editing surfaces and shared controls. Back/Forward history connects tasks, notes and workspace sections; task drafts and selected detail tabs survive navigation. All 158 Swift tests passed, including history branching/bounds and draft retention. The packaged app rebuilt/relaunched and the inline page was visually checked in an isolated sample store. CUA failed before completing the note round-trip; that live interaction remains open. See [navigation evidence](workspace-navigation-18.md).

**Playback indicator:** the static waveform beside the notch mascot is now five animated ember equalizer bars during playback, in both collapsed and expanded headers. The small independent timeline pauses when notch motion is inactive or Reduce Motion is enabled; pausing playback removes the indicator as before. Native build/relaunch (`./script/build_and_run.sh --verify`) and strict signature validation passed. Physical animation/Reduce Motion acceptance remains unverified. Changed `Features/Notch/NotchHUDView.swift` and added `Features/Notch/NotchPlaybackIndicator.swift`.

**Notch crash correction:** the reported constraint-cycle exception identified an oversized NotchPanel. Both HUD and capture now isolate SwiftUI hosting inside an AppKit container so content cannot own panel geometry. All 155 tests pass, including a native 60-transition sizing regression. See [diagnosis and evidence](notch-layout-crash-20.md).

**Dialog styling:** app-owned popups now share Cider’s black/ember surfaces, warm rounded controls and clearer primary actions across agent setup, tasks, note connections, checkpoints, errors, deletion and renaming. All 154 existing tests, a native offscreen visual check, rebuild/relaunch and signature validation passed. See [scope and evidence](dialogs-19.md).

**Agent plugins:** Codex plugin and workflow icons now use Cider’s mascot and ember branding; the installed Codex copy was refreshed and cached assets verified. Codex and Claude Code now have bundled Cider workflow plugins, an optional install checkbox while connecting, install/reinstall/remove controls for existing connections, and an optional removal while disconnecting. Installation uses provider CLI commands and verified status; tracking stays connected if the plugin step fails. All 154 Swift tests, isolated real-provider install/reinstall/remove checks, native rebuild/relaunch and signature validation passed. See [setup](../../Integrations/agent-plugins/README.md) and [evidence](agent-plugins-18.md).

**CLI writes:** the existing CLI now creates/updates tasks and notes, explicitly completes/reopens tasks, adds journal notes and links notes to tasks through the running app. Revision/hash checks and unsaved-draft protection prevent stale edits; direct CLI database access stays read-only. All 149 Swift tests, editor/linked-work checks, packaged read/write CLI checks, normal native rebuild/relaunch and signature validation passed. See [commands](../cli.md) and [implementation/evidence](cli-writes-17.md).

**Working mood follow-up:** live tracking metadata showed two fresh Working agents; the previous sub-point eye motion looked idle at notch size. The mascot now tilts ±7° immediately and alternates every 0.85 seconds, with focused eyes and a still tilted Reduce Motion pose. Five mascot state tests, native rebuild/relaunch, offscreen expression rendering and strict signature validation passed. Physical motion/energy acceptance remains open. See [mascot evidence](mascot-16.md).

**Cider mascot:** the supplied folded-note character replaces the ribbon in the app icon, sidebar and menu bar. The notch now uses native idle, working, needs-you and brief reply-ready expressions driven by tracked activity, with attention priority, stale-state handling, one bounce per fresh response and Reduce Motion/visibility gating. All 145 Swift tests, native render/icon checks, isolated package/CLI launch, normal rebuild/relaunch and signature validation passed. Live motion, hardware and energy acceptance remain unverified. See [behavior and evidence](mascot-16.md).

**Default notes, graph and more providers:** New Note creates and remembers `~/Documents/Cider` when no folder is selected. Graph now indexes unopened notes and wiki links, displays unlinked work, and adds a spring layout, neighbor highlighting, fit/reset and an optional inspector. The screenshot follow-up fixes empty-graph vertical centering and a reproduced scan/open race that assigned conflicting IDs to new notes. Cursor local hooks feed the existing activity/journal/peek flow through reviewed setup. Bundled CodexBar supplies opt-in Cursor/Grok Bot and Grok Build usage in workspace/notch. Schema 2 preserves saved links with a tested recovery backup. All 139 Swift tests, 16 editor checks, linked-work/CLI checks, isolated packaging, normal native build/relaunch and signature validation passed. New provider live activity/usage and graph/hardware acceptance remain unverified; Grok Bot live activity/peeks are not implemented. See [behavior, source evidence and limits](notes-graph-providers-15.md).

**Linked work:** Plans 01–09 are implemented. Plan 09 connects production journal ingestion, workspace graph/actions, saved-context export, checkpoint destination/retry, and packaged CLI/skill setup. The integrated suite passes 124 tests plus editor/fixture/CLI checks; a staged app and CLI work with the original isolated build path unavailable. The normal app was rebuilt and relaunched, and strict signature validation passed. UI acceptance remains deferred to the user. See [implementation evidence](linked-work-14.md).

**Activity and agent connections:** the Agents workspace now separates Activity from Agents setup with shared pill tabs. Activity is the default when a provider is configured or receiving fresh activity; otherwise Agents opens first. Explicit selection and activity filters survive tab switches. Native build/relaunch and live tab/filter/default-navigation checks passed. See [behavior and verification](agents-tabs-13.md).

**Compact usage and pace:** notch usage now uses small gauges; Used/Remaining is shared and persisted across notch/workspace. Its control now shares Cider's rounded HUD pill styling, replacing the blue system selection and wrapping caption; native rebuild/relaunch and live workspace switching verified. Named model limits include live Fable and Codex Spark data. Per-window average-pace estimates show headroom or risk until reset, with unknown/stale guards. The feature's 53 Swift tests passed; the user confirmed both provider rows fit the physical notch before this styling follow-up. See [display, calculation and checks](usage-gauges-12.md).

**Codex chat names:** workspace and notch agent cards now show the exact locally indexed chat name with the workspace below. Names refresh on new activity sessions and every 30 seconds; missing/duplicate names retain a short identity suffix. Native build/relaunch and 45 Swift tests passed. Both requested `df-ai-session` names were resolved and verified in the running Agents workspace. See [title source and verification](agent-titles-11.md).

**Question attention and peeks:** existing Codex/Claude question-tool hooks now retain bounded question text and show a five-second peek with persistent attention. Async delivery/continued work do not clear the question; matching replies do. Native build/launch and 40 Swift tests passed. The user confirmed the live Codex peek/question, and the reply cleared its pending state. See [question behavior and evidence](agent-questions-10.md).

**Automatic usage and Claude recovery:** usage starts with Cider, refreshes every ten minutes and after fresh Stop/SubagentStop events, and shares per-provider loading/last-good values across workspace and HUD. Automatic connection falls back from OAuth to the CLI. Claude subscription probes now exclude inherited Bedrock/Vertex/Foundry routing; live CLI auth confirmed the inherited Bedrock flag masked the existing Max sign-in. Both providers’ quota windows appeared in the rebuilt app. Native build/launch and 33 Swift tests passed. See [refresh policy and verification](usage-refresh-09.md).

**Exact Codex navigation:** activity actions, compact cards and response peeks route desktop-hosted Codex sessions to their task using the recorded session ID. The installed app’s URL router and copy-link implementation confirm the route. Native build/launch and 26 Swift tests passed; the user confirmed Codex now opens the correct chats. See [navigation evidence](agent-navigation-08.md).

**Linked work contracts implemented:** [Plan 01](../plans/linked-work/01-contracts.md) now provides compiled task/chat/note/journal/graph contracts, STRICT SQLite schema and queue-isolation proof, shared UI/navigation seams, unavailable repository/note/CLI seeds, and synthetic fixtures. All three products build and 62 tests pass, including the existing 53. No production migration or hook/skill installation. A CLI smoke test exposed a case-insensitive `Cider`/`cider` build collision; its test app instance was stopped and the CLI build product renamed `cider-cli` (packaged as `cider`). The [worktree overview](../plans/linked-work/00-overview.md) unblocks 02–04 (store, TODO detail, notes) from the pinned contract commit; no parallel agents have been dispatched.

**Click-to-return:** compact agent cards and the complete response peek now activate the recorded source app. Successful activation dismisses/unpins the HUD; missing or exited sources retain the existing explanation instead of opening another app. Peek callbacks capture the responding session and clear on dismissal. Native build/launch and 25 Swift tests passed, including action dispatch and dismissal. Exact terminal tab targeting remains outside current coverage.

**External menu-bar overflow:** runtime window inspection confirmed the HUD remained on the built-in display (345 × 32 points), with the external screen above it. The menu-bar label reused resizable full-resolution artwork; replaced it with an intrinsic 18 × 18 image. HUD hosting now disables automatic window sizing and clips content to its bounds. Native build/launch and 24 tests passed. The external-screen visual correction still needs physical confirmation; user confirmed the response peek works.

**Response Markdown:** workspace/HUD excerpts and response peeks now use native attributed Markdown for emphasis, code and link labels, with normalized headings, bullets and fences. Preview links are inert and images are not fetched. New observer events preserve line breaks; old flattened text cannot recover its original structure. Native build/launch and 24 Swift tests passed, including Markdown rendering and newline preservation.

**Source-app return and header fit:** compact bounded counters keep TODO inside the notch. Observer captures GUI parent identity (PID, launch date, bundle ID) by walking at most 32 ancestors; Open activates that same running app after identity checks, without a Claude Desktop fallback. New events supply provenance for existing sessions. Terminal tab/pane targeting and detached tmux/SSH sources are not covered. Native build/launch, 22 Swift tests and a helper smoke test passed; physical multi-terminal activation remains unverified.

**Agent response peek:** separate agent/task counts, a five-second compact completion peek without full expansion or focus changes, ember gradient outline, and bounded latest-response excerpts. The previously installed helper was verified against the old bundled binary and upgraded without changing hook definitions. Twenty-two Swift tests and native build/launch passed; live peek timing remains to be checked on a new response. See [response refinement](agent-response-07.md).

**Agent tracking implemented:** Cider now includes a bundled metadata-only observer, reviewable Connect/Disconnect, shared durable activity, an Agents workspace and fourth HUD tab. Native modules/app/scripts use Cider; legacy preference/task locations remain compatible. Twenty Swift tests and sixteen WebKit checks passed. Live provider activation and locked-screen UI checks remain explicit gates. See [implementation, evidence and limitations](agent-tracking-06.md).

**Notch capture recovery:** task entry now dismisses on outside clicks, capture focus loss, or tab changes. Tabs remain usable while editing. Ending capture reconciles pointer state and schedules collapse even if the exit event occurred while capture held the HUD open; drafts remain in the model. Focus is not restored over an intentional click elsewhere. Native build/launch and 15 tests passed, including focus-loss/Escape callback coverage. Intermittent physical hover behavior remains a hardware verification gate.

**Note workflow:** Cmd-W closes the active note, Cmd-N creates beside the selected note/in the selected folder, Cmd-S saves, Shift-Cmd-O adds a workspace, and Shift-Cmd-[ / ] switches tabs. Active tabs scroll into view. Folder/file/tab context menus provide creation, open/close, Finder reveal and path copy. The repeated white-table bug was a native scheme-handler rejection of `cider-tables.css`, now explicitly allowed and regression-tested. Native build and 14 Swift/16 WebKit checks passed; interactive shortcuts could not be verified because CUA repeatedly reported app-state changes.

**Folder hierarchy and top spacing:** explicit 18-point nesting with branch guides replaces unindented disclosure content. Tabs now sit 10 points from the window top; only the navigation rail reserves traffic-light space. Added a 12-point divider gutter. Native build/launch passed; visually checked expanded root → docs → child folders and the top-aligned document tab in the running app.

**Table rendering:** Cider table styles now override Vditor’s late-loaded light defaults: dark alternating rows, ember headers, readable text, and wrapping cells. All 16 WebKit checks pass, including five table checks and existing links/Mermaid regressions. Native bundle rebuilt and launched.

**Workspace and media:** nested Markdown tree, linked document tabs, sidebar-mounted toggle, and bundled system Now Playing with artwork, transport, and animated waves. See [implementation and verification](workspace-media-05.md).

**Notch tabs:** expanded HUD now has a rounded Now Playing / TODO / Usage switcher with persistent selection. Usage shares the workspace model; only TODO shows dates and capture. See [tab refinement](notch-tabs-04.md).

**Latest native fixes:** Mermaid editing/rendering and default Cider theme, bundled-only usage setup, centered compact sidebar with persistent collapse, inset HUD capture, and initial Now Playing lookup. See [checks and limits](native-fixes-03.md).

**Native features updated:** window/sidebar/notch refinement, Markdown workspaces, Codex/Claude usage connections, new Cider mark and passive now-playing. See [implementation and evidence](native-features-02.md). Codex OAuth live read succeeded; Claude credential cache is unavailable. The earlier [foundation checkpoint](native-foundation-01.md) remains historical.

**Phase 00 complete:** research, planning, design and interactive prototype. See [phase evidence and handoff](phase-00.md) and [check record](phase-00-checks.json).

**Latest design refinement:** open note editor, inset sidebar and rounded tinted controls. See [revision evidence](design-refinement-03.md) and [current canvas check record](design-refinement-03-checks.json). The Phase 00 record above describes the earlier canvas hash.

## Accepted decisions

- Display name Cider (internal modules remain Cider); black/ember palette with a warm gradient inside the app.
- Native SwiftUI shell, narrow AppKit boundaries, and one lazy Vditor/WebKit editor.
- Independent execution, attention and human verification state.
- HUD anchored to the laptop independently of external-display focus; configurable edge/offset.
- Shared task capture in the day view, toolbar and notch; date arrows/reset, week strip and month calendar.
- Icon actions with tooltips and accessible names; user-facing copy excludes implementation terms.
- Full-page note writing with editable title/body, no input-box outline, and placeholders excluded from content.
- Inset rounded sidebar with nested notes and compact rail; shared rounded, tinted and softly elevated action controls.
- Native system materials and Liquid Glass for suitable chrome/controls; solid accessible reading surfaces.

## Read next

- [Initial plan](../plan/00-initial-plan.md) and [native feasibility work orders](../plan/01-feasibility.md).
- [Task/capture design](../design/tasks-and-capture.md), [native materials](../design/materials.md), [component map](../design/components.md).
- [Writing surface, controls and sidebar](../design/writing-and-sidebar.md).
- [Editor decision](../research/editor-stack.md), [provider capabilities](../research/integrations.md), [repository evidence](../research/reference-codebases.md).
- [Prototype sources](../../design/prototype/README.md); generated canvas at `design/cider-canvas.html`.

## Next native gates

Actual existing-session observation, offline editor round-trip/IME/undo/frontmatter, reliable file/asset persistence, direct notch capture focus, multi-display hardware behavior, accessibility and measured resource use. A canvas interaction does not close these gates.
