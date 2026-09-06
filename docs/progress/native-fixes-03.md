# Native fixes — September 6, 2026

## Delivered

- Mermaid: offline eager load within the lazy editor, Cider base theme, serialized renders, stale-preview protection, preview replacement recovery, and a readable parse-error state. Editing never adds theme directives to Markdown. Local icon fetches now pass the custom-scheme CSP.
- Usage: the app resolves its bundled helper directly, eliminating stale saved paths, installation links and helper setup fields. Build packaging requires the helper and resource bundle, includes the license, and has pinned downloads for Apple silicon and Intel. Provider/account sign-in remains necessary.
- Sidebar: a 64 pt rail with centered mark and 44 pt navigation hit areas; persisted collapse, action-specific tooltips, Control-Command-S, and reduced-motion support.
- HUD: 26 pt outer inset compensates for the 12 pt shoulder inset; capture window uses the same margins and footer position. Expanded height reserves room for three tasks and Now Playing. Date navigation remains available.
- Now Playing: startup/refresh lookup for running Music and Spotify, subsequent track announcements, paused/playing arbitration, stale-read protection, and clearing closed players. Visible empty/permission/error states and refresh action; compact HUD shows a waveform while playing. No browser playback or transport control.

## Verification

- `script/build_and_run.sh --verify`: final app built, signed and launched; `codesign --verify --deep --strict` passed and the arm64 helper/purpose string were present.
- `swift test`: 12 tests pass, including existing persistence/date/geometry/process/usage contracts and four media state regressions. Media tests use synthetic snapshots, not account data.
- `script/verify_editor.sh`: nine native WKWebView checks pass: initial six-node diagram, theme, exact fixture source, inserted diagram, both blocks preserved, invalid syntax feedback, invalid source preserved, rapid refresh recovery and original source retained.
- Native app interaction: pasted the user's six-step flowchart into a new note in the existing isolated `output/qa/native-notes` folder. Observed the diagram with ember styling and verified the saved fenced Markdown. Collapsed sidebar mark and icons align; Control-Command-S expands the rail and collapse survives relaunch; expanded connection settings have no helper path or installation link.
- Offscreen native HUD render with three synthetic tasks confirms content and capture margins and space for Now Playing. This does not verify the physical camera seam or multi-display focus.
- Build/download note: the release host failed a fresh download with a TLS error. Packaging reused the previously downloaded and checksum-verified arm64 release from the local cache. Intel's pinned asset digest was checked against official release metadata; Intel execution was not tested.

## Remaining live checks

Actual Music/Spotify initial-state permission and track changes need a running player; synthetic tests do not prove those Apple events on this Mac. Browser media is outside this adapter. The final native app fetched Codex usage through its included helper. Claude returned unavailable with the current sign-in/cache state and remains an external live gate. No agent-owned settings, hooks or credentials were edited. Release signing/notarization, physical notch seam, clipboard images and IME are separate gates.
