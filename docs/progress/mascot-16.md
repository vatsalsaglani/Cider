# Cider mascot integration

The user handed off the supplied amber folded-note mascot for the app icon, sidebar, menu bar and agent-driven notch. The original PNG and expression SVGs remain in the repository root as the artwork sources. No provider logos or agent settings were replaced.

## Branding and expressions

- `script/build_branding.py` resizes the original transparent `cider-mascot.png` into the shared static branding image and all ten 16–1024 pixel ICNS representations. AppKit places the intact mascot on the charcoal tile from the supplied brand sheet; this prevents macOS from adding a white substrate behind the transparent character. The app's existing `CFBundleIconFile` points at this regenerated icon for Finder/Dock branding.
- Sidebar branding uses a cached static image. The menu-bar image retains its intrinsic 18 × 18 size to prevent the earlier external-menu-bar overflow. Both have a native mascot fallback; installed resources resolve without depending on a SwiftPM build directory.
- The notch uses native SwiftUI paths, gradients and eyes traced from the supplied SVGs. Idle occasionally blinks and breathes; working adds small alternating eye glances; needs-you raises its gaze and one eye; a fresh response shows happy eyes and one small bounce.
- Outstanding attention takes priority across tracked sessions, including child work. Correlated unanswered questions survive stale activity. Other stale/unknown states use the calm expression and an explicit activity freshness label. A historical Stop never produces a reply cue; a new turn cancels the old response expression. Finished responding continues to mean only that an agent responded.
- The five-second cue is transient, driven by fresh ingested notices and an absolute expiry deadline. Animation consumption belongs to the activity model, so tab changes, expansion or view remounts cannot repeat a bounce. Startup/replayed history does not schedule one.
- Reduce Motion uses the still expression and starts no animation task. Sleep, screen sleep, inactive user session, disabled/unavailable notch and panel occlusion stop mascot motion. Focus on an external app does not stop an otherwise visible built-in HUD. Motion sleeps between short transitions; it does not poll each frame or add a WebView.

## Changed surfaces and ownership

`Sources/CiderDomain/CiderMascotState.swift` owns the pure aggregate state. `Features/Agents/MascotActivityModel.swift` owns short-lived reply cues; `AgentTrackingModel` supplies fresh notices. `Sources/CiderUI/Components/CiderMascot*.swift` owns artwork and view-local animation. `NotchHUDView` supplies observed state, and the existing `NotchController` owns system visibility. `AppMark`, `MenuBarMark` and `Resources/branding` provide static branding. Provider branding is unchanged.

## Verification

- `swift test`: **145 tests in 26 suites passed**. New tests cover attention precedence, stale and ended activity, child work, new-turn cancellation, historical completion, one bounce per event and expiry without another provider event. The first run exposed a relative-timer start delay under main-actor load; the cue now expires against an absolute deadline. A synthetic Codex-only error fixture was corrected to use Claude's supported `StopFailure` event.
- `swift build --product Cider` and the normal `script/build_and_run.sh --verify`: passed; the normal app was rebuilt and relaunched.
- An isolated scratch package built and signed successfully. After moving its original build directory aside, the staged CLI passed synthetic verification and the staged native app launched with a fresh fixture root, initialized schema 2 and loaded its folder. The staged process was then stopped.
- `python3 script/verification/verify_mascot.py --app dist/Cider.app --render output/qa/cider-mascot-native.png`: passed. Packaged PNG/ICNS bytes match their source assets; all ten icon representations decode at their expected dimensions. The offscreen native expression sheet was rendered and inspected at large and actual 30-point notch sizes.
- Strict deep signature validation and `git diff --check`: passed.
- A filesystem icon lookup through `NSWorkspace` exposed macOS's cached white substrate from the first transparent-icon build. After adding the charcoal tile, refreshing this app's Launch Services registration returned the new dark icon. The system-resolved icon was rendered and inspected; the final staged icon resources were rechecked and re-signed.

The native sheet validates static artwork, not live animation timing. Physical-notch motion, Reduce Motion/VoiceOver interaction, sleep/lock/multi-display behavior, live provider bursts and energy measurements still need native/hardware acceptance. No CUA was used. The previous default-note/graph/CodexBar work remains intact; its live-integration limits are recorded in [phase 15](notes-graph-providers-15.md).

## Working visibility follow-up

Read-only live tracking metadata confirmed two fresh Codex Working rows. The previous ±7 artwork-unit gaze displacement was only 0.41 points at 30-point notch size, with a 3.6-second initial delay. The working animation now starts immediately, alternates a ±7° tilt and wider glances every 0.85 seconds, and blinks every four beats. Focused shorter eyes distinguish the still artwork; Reduce Motion retains a fixed tilt without running the animation task. Attention, freshness and response priority are unchanged.

Changed `CiderMascot.swift`, `CiderMascotArtwork.swift` and `CiderMascotTests.swift`. All five targeted state tests passed, including one worker among finished agents and return to working after the five-second reply cue. `script/build_and_run.sh --verify`, strict deep signature validation and packaged mascot/render checks passed; `/tmp/cider-working-expressions.png` was visually inspected. Physical animation, accessibility toggling and energy use remain unverified.
