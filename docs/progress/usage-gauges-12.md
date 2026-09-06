# Compact usage gauges, model limits and pace

Implemented 6 September 2026.

## Display

The notch now uses compact provider rows with 36-point circular gauges, short window/model labels, reset countdowns and one scoped pace note. Source freshness stays in the row header. The workspace uses the same component with larger gauges, per-window notes, average consumption and source/account context. Extra model labels such as Spark are shortened in the compact display while their full names and exact reset dates remain in tooltips/accessibility labels.

A Used / Remaining pill control is available in both Usage surfaces. `CiderPillPicker` shares the HUD tab styling: rounded track, quiet warm selection, warm-white labels and a smaller notch size. Native buttons retain selected accessibility traits, semantic group names and tooltips; Reduce Transparency uses solid token surfaces. The visible wrapping picker caption and system-blue selection are removed.

Both bind the same monitor preference, persisted as `usageDisplayMode`. Remaining is exactly `100 - used`; missing or invalid percentages remain unknown. Warning color follows consumption/risk, independent of which percentage is displayed.

## Model-specific limits

The decoder previously kept only primary/secondary/tertiary windows. It now preserves the bundled helper's `extraRateWindows` IDs, titles and window data, plus quaternary windows. Named windows are bounded/deduplicated and never summed into additional capacity. Unknown tertiary model identity is labelled “Model limit,” without guessing a model.

The pinned CodexBar v0.56.6 source (`1696c7a71c94747b99406d1458755e58b2d6bcc4`) confirms the named-window schema and Claude scoped weekly parsing: [CLI parser](https://github.com/steipete/CodexBar/blob/v0.56.6/Sources/CodexBarCore/Providers/Claude/ClaudeStatusProbe.swift), [provider documentation](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/claude.md). Source was inspected as a contract; no provider implementation was copied or dependency version changed.

An initial live CLI probe omitted model-specific limits. A subsequent native app refresh returned Fable, and the UI displayed **21% used / 79% remaining** with its own reset. Codex Spark windows were also returned and displayed. If Fable is absent on a later refresh, the Claude row shows an explicitly unknown “Not reported” gauge, never zero or fabricated capacity.

## Pace method

For each reported window, infer its start from `reset - window duration`. At the observation timestamp, divide used percentage by elapsed time. Extrapolate that same average until reset. Do not use the later UI time to dilute the rate, or convert a session percentage into weekly/model percentages.

- Projected usage below 95%: “On pace,” with approximate percentage spare at reset.
- 95–100%: “Tight.” Above 100%: approximate time until the limit could be reached. An observed 100% reports the limit reached when the window is valid.
- Withhold forecasts for unknown/invalid percentages, missing duration/reset/freshness, elapsed time below 15 minutes, an already passed reset, or observations older than 20 minutes (or significantly in the future).
- The notch selects a warning first, then the most constrained estimable window. Its label identifies the specific window; a new unused Spark window does not hide a meaningful weekly estimate. Workspace notes remain per-window.

These are estimates assuming the observed window-average pace continues, not assurances about future workloads. Overlapping model limits remain independent. Views update visible time labels once per minute; the existing ten-minute/Stop-event fetch schedule is unchanged.

## Verification

- `swift test`: all **53 tests passed**, including complementary percentage modes, unknown/invalid values, enough/tight/exhausted/running-out cases, early/reset/stale windows, observation-time math, fractional ISO timestamps, named Fable windows, duplicates, missing Fable and persisted display mode.
- `script/build_and_run.sh --verify`: app/helper built, signed and relaunched successfully.
- Native workspace screenshot/accessibility inspection showed Codex weekly/Spark and Claude session/weekly/Fable gauges, reset countdowns and pace notes.
- Live switch check changed Codex 72% used to 28% remaining, Claude 2% to 98%, weekly 13% to 87%, and Fable 21% to 79%, while keeping pace estimates unchanged.
- The user confirmed that both compact provider rows, including Fable, fit in the physical notch without the previous clipping. Automated system-menu inspection timed out; this is user-confirmed hardware verification rather than a separate captured notch screenshot.
- Pill-style follow-up: native app rebuilt/relaunched and the workspace control visually inspected. Clicking Used/Remaining moved the selected accessibility trait and complemented the live percentages. This styling-only change reused the existing preference/calculation behavior; no new unit tests were added. A separate physical notch screenshot was not captured for this follow-up.

Changed paths: `ProviderUsage`, `UsagePace`, `UsageMonitor`, reusable `UsageRing`, shared `UsageProviderCard`, workspace/notch usage views, configurable `BrandImage` size, usage tests and progress docs. No provider credentials, hook definitions, auth settings or dependency versions were edited.
