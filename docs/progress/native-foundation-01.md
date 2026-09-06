# Native foundation checkpoint — 2026-09-06

## Implemented

- Swift 6 package with Domain, Data, UI, Platform and App boundaries; macOS 26 minimum.
- Actual Cider.app bundle and Codex Run action via script/build_and_run.sh.
- Built-in-display notch controller, edge/offset preferences, passive expansion, pinning and a separate explicit keyboard capture panel.
- Shared task composer in Today, toolbar quick capture and notch.
- Atomic task/preferences persistence; completion and edit sheet; day arrows/reset, week strip and month grid.
- Generated Swift color tokens, ember background, inset material sidebar and shared glass icon controls.

## Verified

- `swift build`: passed with Swift 6.3.
- `swift test`: four tests passed: nonzero/negative display geometry, DST calendar arithmetic, invalid day rejection, persistent snapshot/corrupt-file retention and stale revision behavior.
- `./script/build_and_run.sh --verify`: passed, real .app launched.
- Native CUA inspection: entered “Verify native task capture”; task appeared; completed it; relaunched app; completed count remained one.
- Native screenshot inspected; corrected the gradient's visible hard edge.

The completed QA task remains in the local app workspace, identifiable by the title above.

## Not yet verified / remaining work

- Direct notch keyboard capture, hover focus, external monitor, clamshell, Spaces and reconnect behavior need hardware interaction checks. Geometry unit coverage is not hardware verification.
- Notes/folders and usage/connections are not implemented in this checkpoint. Follow docs/plan/03-native-priorities.md.
- Task undo/deletion/order, restart-recoverable drafts, richer calendar workflows and accessibility audit remain.
- No live provider credentials or configurations inspected or changed. No release signing/notarization, measured memory/CPU budget or full editor feasibility gate completed.
- Snapshot storage deviation and migration gate recorded in the priority plan.
