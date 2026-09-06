# Verification and performance gates

This checklist describes future native acceptance. Phase 00 results are recorded separately in [current progress](progress/current.md).

## Meaningful automated checks

| Boundary | Evidence |
| --- | --- |
| State reduction | Duplicate/out-of-order events, terminal-state protection, stale source, separate human verification, same-name repositories, changed tested revision |
| Persistence | Atomic event/projection updates, migration failure leaves recoverable backup, outbox reconciliation, restart replay |
| Files | External edits/atomic replacement, missing volume, permission denial, Unicode paths, symlinks, asset/Markdown crash journal, read-only and full-disk failures |
| Editor | No-op bytes, supported semantic round-trip, unknown blocks, YAML preservation, selection/revision ordering, image paste/undo, Mermaid error containment |
| Adapters | Versioned fixtures, interleaved JSON-RPC replies/events, null quota fields, sparse updates, auth expiry, timeout/cancellation, capped output, no secret logs |
| Geometry | Negative origins, varying scale, hardware exclusion, no notch, offsets, Dock bounds, disconnected preferred display |

Use Swift Testing for domain/adapter/storage units and XCTest/XCUITest for real app interactions where needed. Do not add brittle tests that simply match view implementation strings. Snapshot tests complement keyboard/accessibility checks rather than replacing them.

## Native editor acceptance

Task/date acceptance is also required: [task and capture checklist](design/tasks-and-capture.md). Test all three composers against one store, duplicate submit, save failures, calendar boundaries/DST/timezone/midnight, direct notch typing and focus restoration, and icon-only actions with tooltip/VoiceOver/menu access. [Material verification](design/materials.md) includes native glass and solid accessibility fallbacks.

With networking disabled, open the P01-B fixture and verify live headings/lists/tasks/tables, Swift/TypeScript/Python/JSON highlighting, Mermaid flowchart/sequence/Gantt, code copy, and raw-source editing. Paste five screenshots; confirm unique files under the configured per-note asset folder and relative Markdown links. Change workspace/default/per-file asset policy and verify precedence. Open the result in another editor.

Test CJK/Indic IME composition, emoji and combining characters, undo/redo across paste, selection across blocks, Cmd-F/Cmd-S, spellcheck, VoiceOver, and keyboard focus between WebKit/native header/sidebar. Paste after changing tabs while an image is decoding; the result must land in the intended note or fail visibly, never the current unrelated note.

Test source-preserving treatment of unsupported syntax, frontmatter comments/arrays/multiline values, invalid YAML, malformed Mermaid, huge graphs, external images, injected HTML/scripts and traversal links. Verify no remote/native actions occur just from rendering.

## Physical display matrix

| Configuration | Must observe |
| --- | --- |
| MacBook only with camera housing | Hardware-safe controls, natural hover, correct edge attachment |
| External primary, external app focused | Laptop HUD remains; hover does not activate Cider |
| Full-screen app on laptop / external | Document exact supported visibility, Spaces and focus behavior |
| Different scale factors and negative origins | No gaps, misplaced panels, clipped text or off-screen actions |
| Top/left/right/bottom plus Dock auto-hide | Placement persists and avoids essential system UI |
| Unplug/replug, resolution change, sleep/wake | One valid panel, no duplicate observers, restored preference |
| Closed-lid/external-only and reopening | Explicit fallback and restoration, no promise of pixels on a closed screen |
| No-notch display, mirrored displays | Sensible synthetic tab, stable fallback |

Also click through transparent panel areas, move into popovers, pin/unpin, open text capture, and use keyboard/menu-bar recovery. Permission-denied behavior must remain usable without Accessibility or Screen Recording.

## Live agent acceptance

Record exact Codex/Claude/Cursor versions and enabled source capability. Use at least two independent sessions in distinct worktrees while one asks for input and another finishes. Compare Inbox with source app. Stop/restart the connector and app; no lost or duplicate unresolved requests. Do not close this gate based on fresh rollout timestamps alone.

Verify that opening the source does not send text/approval. For any later reply/approval action, test the exact request ID, destination and acknowledgement on a designated test session. Unknown capabilities must stay disabled.

Jira mutations use a designated test issue and explicit authorization. Quota live skips due to unavailable credentials are reported as skipped, not passed.

## Resource measurements

Use a release `.app` on the user's Mac, record OS/toolchain/hardware and warm/cold state. Fixture A: collapsed HUD, 3 features/12 lane records, 20 sessions, 10k stored events, no editor. Fixture B: one 20k-character note, five 1920×1080 screenshot assets, highlighted code and one moderate Mermaid graph. Stress: 1 MiB document, 100 active/inactive session records, burst of 100 events/second for ten seconds.

| Metric | Proposed acceptance target | Method |
| --- | --- | --- |
| Collapsed footprint | ≤80 MiB | Physical footprint, app + attributable helpers, after settling |
| Rich-editor footprint | ≤250 MiB combined | Include WebKit web-content/GPU attributable cost; report attribution limits |
| Idle CPU | <0.5% of one core average | Ten minutes after settling; providers enabled, scheduler state recorded |
| Idle wakeups | ≤1 per second average target | Energy/Instruments; identify source of unavoidable system wakeups |
| Hover/input | p95 <16 ms input-to-display; frame work ≤8.3 ms at 120 Hz | Signposts and Instruments; also test 60 Hz |
| Event to Inbox | p95 <250 ms app-owned latency | Timestamp from local ingest to projection; provider latency separate |
| Growth | No continuing retained growth over 100 open/close cycles | Allocations/leaks; inspect editor handlers, monitors and task ownership |

If a target is missed, show the measured result and dominant cost before changing the target. Keep source-derived design expectations separate from benchmarks. No perpetual particle/glow animation, recursive workspace scans on hover, or unbounded transcript hydration.

## Release checks

Keyboard/VoiceOver traversal; Increase Contrast/Reduce Transparency/Reduce Motion; long text and increased font size; data backup/restore; migrations; bookmarks/permission loss; provider revocation; hook install/remove idempotence; app launch/quit/login behavior; code signing, hardened runtime, notarization/Gatekeeper; packaged licenses; fresh install and upgrade. Native tests, hardware tests and live tests have separate result records.
