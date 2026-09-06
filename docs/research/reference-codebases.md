# Cider reference-codebase research

Research date: 2026-09-06  
Scope: source inspection only; no reference application was built, launched, or given credentials.

## Executive conclusion

Cider should use an AppKit-owned, non-activating `NSPanel` for its notch
surface, with SwiftUI inside a deliberately sized container. This is the most
reusable pattern in both notch references. Do not adopt either application as
an architectural base: Codenotch is a small, purpose-specific usage overlay,
SwiftSnes is an emulator with focus-capture requirements, and CodexBar is a
large multi-provider menu-bar product.

The product-defining capabilities Cider needs—parallel-run topology,
worktrees, verification/approval queue, local TODOs, Jira, and rich notes—are
not implemented together in any reference. They need Cider-owned domain
models and explicit adapters. In particular, a “recent rollout write” is not
an approval signal, and no inspected source provides a safe generic mechanism
to approve another agent’s action.

## Method and reproducibility

All repositories were shallow-cloned into the disposable, outside-workspace
directory `/tmp/cider-research-20260906/`. Remote URLs and checked-out commits:

| Reference | Verified remote / owner | Commit inspected | Commit timestamp | License evidence |
| --- | --- | --- | --- | --- |
| Codenotch | `vinzdg/codenotch` | `e7438f769a31d168753dc4332bde7f32f0fef4ef` | 2026-09-05T22:27:56+07:00 | No `LICENSE`/`COPYING` file at repository root; no license claim found in the inspected root docs. Treat as unlicensed unless the owner clarifies. |
| NotchSnes / SwiftSnes | `aricarmo/SwiftSnes` | `6efe79a643ab8106493a448cec369a41627412d1` | 2026-09-04T10:15:03-03:00 | No root license file. Its README says “To be defined”; do not reuse source or art. |
| CodexBar | `steipete/CodexBar` | `3a676e143e230d4ae71121c8a1e7942cb87b3f7a` | 2026-09-05T11:42:10-07:00 | MIT, in [`LICENSE`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/LICENSE#L1-L21). |

“Authoritative CodexBar” was resolved before cloning: GitHub search results
identified the release repository as `steipete/CodexBar`; the cloned `origin`
was `https://github.com/steipete/CodexBar.git`. Forks with similar names were
not used as authority.

Evidence below is source inspection at the pinned commits. Claims marked
“tested” mean that the source includes automated tests or test seams; they do
not mean this research session ran those tests. No UI behavior was exercised.

## Comparison at a glance

| Concern | Codenotch | SwiftSnes | CodexBar | Cider decision |
| --- | --- | --- | --- | --- |
| Overlay shell | Borderless non-key `NSPanel`, edge-selectable | Borderless panel, becomes key for game input | Menu-bar app, not a notch overlay | Adopt Codenotch’s non-activating shell. |
| SwiftUI sizing | AppKit geometry owns window size; container prevents `NSHostingView` resizing it | Measures a second hosting tree, then owns geometry | Large AppKit/SwiftUI menu composition | Keep Cider geometry controller outside views. |
| Hover | Global + local monitor plus low-frequency poll and grace periods | Global + local monitor plus 100 ms poll and state machine | Not applicable | Adopt Codenotch-style event + poll fallback, but profile it. |
| Display policy | `NSScreen.main` | First screen with hardware notch, else main | Notch-free | Neither meets Cider’s built-in-display requirement exactly. |
| Agent state | Provider-specific files/SQLite; Codex is a recency heuristic | None | Process + bounded metadata scan; active/idle only | Define adapter capability and confidence, never pretend a heuristic is approval. |
| Session action | Refresh, open settings | Captures/relinquishes keyboard | Focus existing session, optionally via Accessibility | Cider should open/focus a task; its approval queue must be Cider-owned. |
| Usage | Four narrow adapters, local-first plus Codex app-server | None | Mature but broad multi-source registry | Borrow abstraction and bounded refresh patterns, not provider breadth. |
| Reuse risk | No declared license | Explicitly undecided license | MIT, but high dependency/product coupling | Reimplement small patterns; do not copy from first two. |

## Codenotch: architecture and notch mechanics

### Architecture

- Its SwiftUI `App` has only an empty `Settings` scene; `AppDelegate` owns the
  panel and services. See [`CodenotchMain.swift:3-11`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/App/CodenotchMain.swift#L3-L11).
- `AppDelegate` wires preferences, `UsageStore`, provider monitors, settings,
  a status item, and the notch controller; the UI observes main-run-loop
  publications. See [`AppDelegate.swift:35-203`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/App/AppDelegate.swift#L35-L203).
- It makes a deliberate activation-policy choice, then lets a preference switch
  it between regular/accessory behavior. See [`AppDelegate.swift:26-33`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/App/AppDelegate.swift#L26-L33) and [`AppDelegate.swift:120-129`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/App/AppDelegate.swift#L120-L129).
- The view model is `@MainActor`, `ObservableObject`, and holds display state
  separately from settings: hovered, expanded, pinned, always-on, refreshing,
  edge, and screen-derived geometry. See [`NotchViewModel.swift:4-73`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchViewModel.swift#L4-L73).

### Panel, focus, spaces, and event pass-through

- `NotchPanel` is borderless and non-activating, at `.statusBar` level, joins
  all Spaces, stays stationary, and is a full-screen auxiliary window. It
  cannot become key or main. See [`NotchPanel.swift:34-54`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchPanel.swift#L34-L54).
- This is directly suitable for Cider’s “do not steal focus from the app on
  another monitor” goal. Cider should preserve non-activation for the compact
  notch and open a normal window or popover for any long editing task.
- The controller defaults the panel to `ignoresMouseEvents = true`, enables it
  only when the cursor is in calculated live regions, and uses a hosting-view
  interaction mask. See [`NotchWindowController.swift:109-144`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L109-L144) and [`NotchWindowController.swift:201-244`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L201-L244).
- It intercepts right-click and left-click at the `NSPanel` level because a
  SwiftUI hit view can consume the event first. See [`NotchPanel.swift:7-32`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchPanel.swift#L7-L32).
- The controller keeps SwiftUI from changing the panel’s frame by placing the
  hosting view inside an AppKit container. The source documents a real
  `GeometryReader` ideal-size collapse on horizontal edges. See [`NotchWindowController.swift:114-133`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L114-L133).

### Geometry, hardware notch, and displays

- Geometry is in testable pure-ish types: `ScreenDescribing`, `HardwareNotch`,
  `NotchGeometry`, `NotchPlacement`, `NotchEdge`, and `NotchLayout`. That
  separation is highly adoptable. See [`NotchGeometry.swift:3-22`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchGeometry.swift#L3-L22) and [`NotchPlacement.swift:3-77`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchPlacement.swift#L3-L77).
- It calculates a hardware cutout from `auxiliaryTopLeftArea`,
  `auxiliaryTopRightArea`, and `safeAreaInsets.top`; no cutout means no
  hardware notch. See [`NotchGeometry.swift:24-39`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchGeometry.swift#L24-L39).
- It attaches edges to `visibleFrame` but centers side bars using `frame`. This
  avoids the Dock while preventing an unrelated Dock from moving a side bar.
  Frames are rounded outward to eliminate a wallpaper hairline. See [`NotchGeometry.swift:42-97`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchGeometry.swift#L42-L97).
- Its top bar merges with a hardware notch by using `frame.maxY` instead of the
  visible top. `NotchViewModel` also reserves the hardware notch height as a
  content inset. See [`NotchGeometry.swift:77-89`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchGeometry.swift#L77-L89) and [`NotchViewModel.swift:63-99`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchViewModel.swift#L63-L99).
- Its chosen display is simply `NSScreen.main`. See [`NotchGeometry.swift:99-102`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchGeometry.swift#L99-L102). This does **not** prove that it remains on a built-in display when an external-display app is focused.
- It relocates on screen-parameter notifications and compares `visibleFrame`
  every 0.3 seconds to catch auto-hiding Dock changes that do not notify it.
  See [`NotchWindowController.swift:54-85`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L54-L85) and [`NotchWindowController.swift:246-294`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L246-L294).

### Hover and interaction state

- It uses both global and local mouse monitors because the panel initially
  ignores mouse events, then supplements them with a 0.3-second timer for a
  stationary cursor. See [`NotchWindowController.swift:246-280`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L246-L280).
- It applies a 0.25-second hover grace and 0.45-second fold grace via cancelled
  `DispatchWorkItem`s; pinning is independent of “always show.” See [`NotchWindowController.swift:35-44`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L35-L44), [`NotchWindowController.swift:321-370`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L321-L370), and [`NotchViewModel.swift:21-35`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchViewModel.swift#L21-L35).
- Edge changes crossfade the panel out, relocate while invisible, then re-open;
  they do not animate a bar around a screen corner. See [`NotchWindowController.swift:413-478`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L413-L478).

### Agent status and approvals

- Its normalized `AgentSession` has `busy`, `waiting`, and `idle`, plus an
  optional `waitingFor` display string. See [`AgentSession.swift:3-26`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/AgentSession.swift#L3-L26).
- Claude sessions are file-watched, debounced, and checked against process
  liveness; the PID start-time check avoids a reused PID reviving stale state.
  See [`ClaudeSessionMonitor.swift:5-103`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/ClaudeSessionMonitor.swift#L5-L103) and [`ProcessLiveness.swift:3-42`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/ProcessLiveness.swift#L3-L42).
- Cursor maps `hasBlockingPendingActions` or `hasPendingPlan` to `waiting` and
  `unfinishedRunAt` to `busy`, while reading SQLite without `immutable` so WAL
  updates are visible. See [`CursorActivityMonitor.swift:6-17`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/CursorActivityMonitor.swift#L6-L17) and [`CursorActivityMonitor.swift:55-94`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/CursorActivityMonitor.swift#L55-L94).
- Codex has no inspected authoritative state field in this code. The monitor
  treats the latest rollout/catalogue modification within eight seconds as
  `busy`, and labels the result “Working.” The source calls this a heuristic.
  See [`CodexActivityMonitor.swift:5-16`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/CodexActivityMonitor.swift#L5-L16) and [`CodexActivityMonitor.swift:62-103`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Sessions/CodexActivityMonitor.swift#L62-L103).
- Codenotch renders waiting information but has no source-inspected action that
  approves/rejects an agent request. A ring click refreshes a provider, and the
  settings handle opens settings. See [`NotchWindowController.swift:391-410`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Notch/NotchWindowController.swift#L391-L410).

### Usage adapters and refresh behavior

- `UsageStore` retains last-good readings, distinguishes stale/error/auth state,
  skips disconnected providers before reading credentials, serializes global
  refresh, refreshes a single provider independently, and refreshes more slowly
  when nothing is busy. See [`UsageStore.swift:5-57`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Model/UsageStore.swift#L5-L57), [`UsageStore.swift:133-200`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Model/UsageStore.swift#L133-L200), and [`UsageStore.swift:287-329`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Model/UsageStore.swift#L287-L329).
- Its Codex adapter first spawns the local `codex app-server` to call
  `account/rateLimits/read`; it falls back to the tail of the newest local
  rollout and labels old readings stale. See [`CodexLocalProvider.swift:5-15`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Providers/CodexLocalProvider.swift#L5-L15), [`CodexLocalProvider.swift:28-115`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Providers/CodexLocalProvider.swift#L28-L115), and [`CodexBridge.swift:55-123`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Providers/CodexBridge.swift#L55-L123).
- It parses the reply by JSON-RPC id because notifications can interleave, and
  handles both `resets_at` and `resets_in_seconds` in rollout data. See [`CodexBridge.swift:112-123`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Providers/CodexBridge.swift#L112-L123) and [`CodexUsage.swift:20-114`](https://github.com/vinzdg/codenotch/blob/e7438f769a31d168753dc4332bde7f32f0fef4ef/Sources/Providers/CodexUsage.swift#L20-L114).

## SwiftSnes: useful notch interactions, unsuitable ownership

### What to borrow

- The app likewise has an empty SwiftUI scene and creates its interface from an
  app delegate. See [`SNESEmulatorApp.swift:10-20`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/SNESEmulatorApp.swift#L10-L20).
- Its `PassthroughContainerView.hitTest` makes the transparent remainder of a
  taller panel click through. See [`NotchWindowController.swift:14-26`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L14-L26).
- It measures a duplicate SwiftUI root before creating the visible host and
  disables host sizing options; the panel remains controller-owned. See [`NotchWindowController.swift:93-137`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L93-L137).
- It keeps the physical panel tall enough for expanded content and animates a
  top-anchored SwiftUI mask instead of continuously shrinking the window. This
  avoids clipped overflow while preserving pass-through outside visible content.
  See [`NotchWindowController.swift:211-273`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L211-L273) and [`NotchRootView.swift:204-239`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchRootView.swift#L204-L239).
- Its presenter is a compact, explicit state machine: hover, expand, pin,
  settings, keyboard rebinding, input ownership, and delayed enter/leave. See
  [`NotchPresenter.swift:7-108`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchPresenter.swift#L7-L108).
- It combines global and local event monitoring with a 100 ms location poll to
  survive inactive panels and cursor movement without events. See
  [`NotchPresenter.swift:110-151`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchPresenter.swift#L110-L151).

### Why not to copy its focus behavior

- The panel overrides `canBecomeKey` to `true`, and the controller can activate
  the app, make the panel key, then later reactivate the previous application.
  See [`NotchWindowController.swift:9-12`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L9-L12) and [`NotchWindowController.swift:358-380`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L358-L380).
- That behavior is appropriate for a game needing keyboard capture, but conflicts
  with Cider’s requirement to stay on the built-in display while the user works
  on another display. Cider should not capture focus on hover or normal click.
- SwiftSnes chooses the first display reporting a top safe-area inset, otherwise
  `NSScreen.main`. See [`NotchMetrics.swift:76-105`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchMetrics.swift#L76-L105). This is closer to “hardware-notch display,” but it is not a durable built-in-display identity policy and is not dynamically re-anchored on display changes.
- Its source shows extensive main-actor UI coordination and deliberately sends
  frames directly to a layer rather than publishing them through SwiftUI. See
  [`NotchWindowController.swift:275-334`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/UI/NotchWindowController.swift#L275-L334) and [`EmulatorViewModel.swift:44-76`](https://github.com/aricarmo/SwiftSnes/blob/6efe79a643ab8106493a448cec369a41627412d1/snes/EmulatorViewModel.swift#L44-L76). The general lesson—avoid high-frequency observable state—is adoptable.

## CodexBar: robust adapters, bounded scanning, and limits

### Architecture and coupling

- CodexBar publishes a core library, app, CLI, widget, watchdog, and replay
  tools; its manifest also pulls Sparkle, KeyboardShortcuts, Vortex, Commander,
  Crypto, Logging, and SweetCookieKit. See [`Package.swift:22-52`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Package.swift#L22-L52) and [`Package.swift:76-214`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Package.swift#L76-L214).
- Its README describes a multi-provider menu-bar app with local files, OAuth,
  browser cookies, API keys, provider CLIs, widgets, and optional status polling.
  See [`README.md:14-24`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/README.md#L14-L24) and [`README.md:150-166`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/README.md#L150-L166).
- It is valuable as an implementation-pattern reference, but importing its
  provider registry or UI would bring product scope and dependency coupling
  far beyond Cider’s initial purpose.

### Agent session collection and action boundary

- Its public session model represents provider, source, active/idle state, PID,
  cwd/project, optional name and transcript path, timestamps, and host. It has
  no `waiting`, approval, or verification-request state. See [`AgentSession.swift:3-69`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/AgentSession.swift#L3-L69).
- The scanner bounds filesystem work: default active window 120 seconds,
  rollout count 128, directory entries 512, depth one, and 0.25-second local
  budget. See [`AgentSession.swift:72-108`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/AgentSession.swift#L72-L108).
- It gets agent processes, filters helpers, resolves CWDs, scans only today and
  yesterday’s rollout directories, reads first-line metadata, then correlates
  process, cwd, and rollout. See [`LocalAgentSessionScanner.swift:93-188`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/LocalAgentSessionScanner.swift#L93-L188), [`LocalAgentSessionScanner.swift:236-350`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/LocalAgentSessionScanner.swift#L236-L350), and [`LocalAgentSessionScanner.swift:415-459`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/LocalAgentSessionScanner.swift#L415-L459).
- Its store scans every 30 seconds locally and every 60 seconds remotely only
  when user settings permit it; adaptive-only mode retains the latest activity
  timestamp but discards names and paths. See [`AgentSessionsStore.swift:136-166`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBar/AgentSessionsStore.swift#L136-L166), [`AgentSessionsStore.swift:186-251`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBar/AgentSessionsStore.swift#L186-L251), and [`AgentSessionsStore.swift:258-297`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBar/AgentSessionsStore.swift#L258-L297).
- Clicking a local session attempts to activate the associated app and, only
  with Accessibility trust, raises a window matching project/cwd. It does not
  steer a task or approve a request. See [`SessionWindowFocuser.swift:28-45`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/SessionWindowFocuser.swift#L28-L45) and [`SessionWindowFocuser.swift:47-95`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/SessionWindowFocuser.swift#L47-L95).
- Cider should make “focus task” an optional adapter action with a visible
  accessibility-permission explanation; it must offer a normal fallback when
  trust is absent.

### Usage and refresh patterns

- CodexBar’s README explicitly scopes adaptive agent-aware scanning behind
  consent and says it reads bounded known metadata rather than crawling disk.
  See [`README.md:168-182`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/README.md#L168-L182).
- Its adaptive scheduler considers menu-open time, coding activity, low-power
  mode, and thermal state; fixed timers skip overdue intervals rather than
  creating overlapping catch-up refreshes. See [`UsageStore+AdaptiveRefresh.swift:24-46`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBar/UsageStore+AdaptiveRefresh.swift#L24-L46) and [`UsageStore+AdaptiveRefresh.swift:74-115`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBar/UsageStore+AdaptiveRefresh.swift#L74-L115).
- Its `BoundedTaskJoin` races a source task against a timeout, resolves once
  under a lock, and cancels the source on timeout/caller cancellation. This is
  a good pattern for optional enrichment, not for core local persistence.
  See [`BoundedTaskJoin.swift:3-80`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/BoundedTaskJoin.swift#L3-L80).

### Hooks are not a generic approval protocol

- CodexBar hooks emit quota/provider events only: low/reached/reset, provider
  unavailable/recovered, and refresh failure. See [`HookEvent.swift:3-27`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/Hooks/HookEvent.swift#L3-L27).
- Hook payloads are intentionally small, non-secret event metadata carried by
  environment variables and JSON stdin. See [`HookEvent.swift:29-95`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/Hooks/HookEvent.swift#L29-L95).
- Rules require an absolute executable path, cap argument/count/byte size, and
  limit timeouts to 0.1–300 seconds. See [`HookRule.swift:3-106`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/Hooks/HookRule.swift#L3-L106).
- The runner invokes a binary directly, forwards a narrow environment allowlist,
  bounds payload size to 4 KiB, uses a timeout, and redacts stderr/payload from
  error logs. See [`HookRunner.swift:3-53`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/Hooks/HookRunner.swift#L3-L53) and [`HookRunner.swift:56-107`](https://github.com/steipete/CodexBar/blob/3a676e143e230d4ae71121c8a1e7942cb87b3f7a/Sources/CodexBarCore/Hooks/HookRunner.swift#L56-L107).
- This safety shape is adoptable for Cider’s future export/notification hooks,
  but hooks must stay opt-in and must not be a covert way to act on approvals.

## Recommended Cider technical shape

1. Create a narrow `NotchOverlayController` on `@MainActor` that owns one
   `.borderless` + `.nonactivatingPanel`, pass-through hit testing, screen
   relocation, and a SwiftUI `CiderNotchRootView` inside a fixed container.
2. Separate `NotchPresentationState` from persistent domain state. The former
   should contain hover/expanded/pinned/selection; the latter should contain
   projects, feature phases, runs, worktrees, verification requests, TODOs,
   notes, attachments, and optional Jira links.
3. Use a `DisplayAnchor` policy: prefer an explicitly saved display identifier;
   otherwise detect the built-in display with CoreGraphics display identity,
   then fall back to the hardware-notch display, then primary. Re-evaluate on
   display configuration change, not app-focus change.
4. Keep the notch non-key. A tap can expand it but must not call
   `NSApp.activate` or `makeKey`; editing long notes, reviewing a diff, or
   resolving a verification item should open a separate normal Cider window.
5. Define `AgentRunAdapter` with fields such as `runID`, `source`,
   `state`, `confidence`, `updatedAt`, `projectID`, `worktreePath`, and
   capability flags (`canFocus`, `canOpen`, `canApprove`), rather than binding
   UI directly to rollout formats.
6. Model a human verification queue independently as append-only
   `VerificationRequest` records with required evidence, owner, resolution,
   timestamp, and a source adapter reference. Do not infer it from text or
   status-file freshness.
7. Store notes as local folder-backed Markdown plus an asset directory per note.
   Render Mermaid and syntax-highlighted code in the detail window, not the
   compact notch. Treat pasted assets as managed copies with stable relative
   links and metadata for deletion/repair.
8. Make Jira an optional outbound integration. A failed/absent adapter must not
   block local tasks, verification, notes, or phase tracking.

## Bounded technical spikes before implementation

| Spike | Scope and success condition | Risk retired |
| --- | --- | --- |
| Built-in-display anchor | Prototype a non-activating top/left/right panel on a MacBook plus external monitor. Focus and full-screen apps on the external display must not move, activate, or hide the built-in panel. Verify replug, sleep/wake, menu-bar move, and Dock changes. | The central multi-display promise. |
| Input/pass-through | Exercise hover, click, right-click, drag across tooltip/popover gaps, and clicks on the transparent expanded panel remainder. Verify no click leaks onto Cider chrome and no intercepted click reaches the app below. | Incorrect hit regions and focus theft. |
| Codex state adapter | Read only bounded local metadata and compare a live process, a recent rollout, and an idle task. Publish confidence labels (`authoritative`, `inferred`, `unknown`); no approval action. | False “running/waiting” claims. |
| Approval queue | Build a mock adapter emitting an explicit request. Verify resolve/decline/audit behavior offline and make direct approval unavailable unless an adapter advertises it. | Unsafe UI-driven automation. |
| Note asset round-trip | Create a Markdown note, paste image/PDF assets, rename/move note folder, render code and Mermaid, then reopen/reindex. | Broken local knowledge base links. |
| Performance budget | Instrument scan, persistence, Markdown render, and overlay recomposition. The compact surface should display cached data while background tasks are bounded/cancellable. | Jank or energy use from scanning. |

## Explicit non-adoptions and risks

- Do not copy Codenotch or SwiftSnes source: neither repository declares a
  reusable license at the inspected commit.
- Do not use SwiftSnes’s key-window / previous-app restoration approach; it is
  intentionally optimized for game input, not a productivity overlay.
- Do not adopt Codenotch’s Codex freshness heuristic as Cider truth. Show it
  only as “recent local activity” with a timestamp and confidence.
- Do not scrape agent UI to press approval buttons. That is brittle, can require
  Accessibility privilege, and lacks a safe cross-agent semantic contract.
- Do not initially vendor CodexBar. Even though it is MIT, it is a high-velocity,
  multi-provider app with broad external dependencies and a different product
  boundary. Recreate only independently understood, small patterns.
- Do not run full filesystem scans on hover. Bound and consent-gate all local
  activity inspection; retain minimal identifiers when the detailed session UI
  is disabled.

## Verification status

- Completed: remote/owner verification, shallow clone, commit pinning, root
  license-file inspection, source and test-seam inspection, and clean-clone
  status check.
- Not performed: builds, unit tests, UI launch, agent login, provider API calls,
  credential access, Accessibility permission, process control, app-server
  execution, display/focus testing, or external side effects.
- Therefore: all behavior conclusions are source-derived and should be validated
  by the two display/input spikes before Cider’s notch implementation commits.
