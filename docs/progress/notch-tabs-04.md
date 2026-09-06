# Notch tabs — September 6, 2026

The expanded HUD follows the original segmented design with three separate panels:

- Now Playing: dedicated music status, empty/permission/error states and refresh.
- TODO: previous/next day, return to today, task completion and quick capture.
- Usage: Codex/Claude quotas, account/window/reset/update context, unavailable states and refresh.

The shared pin and workspace actions stay outside panel content. Selection persists across closing/reopening the HUD and relaunch. Tab switching is disabled while the capture panel owns keyboard focus so a floating input cannot remain above another tab. The capture field remains anchored at the existing 60 pt footer offset.

The app owns one UsageModel for both the workspace and HUD. Readings, provider toggles and in-flight refreshes are shared, and tab changes retain results. Usage fetches on first opening when no result or error exists; later requests are explicit.

Verification: Swift build/run verification and all 12 existing tests pass. Native rendering inspected TODO with three synthetic tasks, Now Playing empty state and Usage unavailable cards at 440 × 382 pt. The Usage scroll area was verified through an NSHostingView bitmap, since ImageRenderer does not capture its native scroll surface. These are isolated native render checks, not a new physical-notch or live-provider validation. Earlier provider and media limitations remain in native-fixes-03.md.
