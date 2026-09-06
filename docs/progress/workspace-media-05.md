# Workspace navigation and system media

Implemented on 6 September 2026.

- Sidebar toggle lives at the top of the collapsed rail and in the expanded brand row. Removed the separate full-width header; capture actions live in the sidebar.
- Workspace navigation preserves nested folders with expandable rows and full Markdown filenames. Selecting a linked note expands its ancestors.
- Open documents have selectable, closable tabs. Switching saves the current note before loading another into the single editor. A concurrent edit prevents replacement; failed saves keep the writing open.
- Click rendered link labels in Vditor editing mode or ordinary rendered anchors. Relative Markdown links resolve against the current file and open in tabs, with heading-fragment navigation. HTTP/HTTPS/mailto links use the default app. Other schemes are rejected; local notes must remain inside selected workspace folders.
- Now Playing uses a bundled system-media adapter with a full-snapshot event stream. Browser sessions exposed by macOS can supply title, artist, artwork, and playback state. Previous/play-pause/next send system transport commands. The sine animation reflects playing/paused state, is decorative rather than sampled audio, and honors Reduce Motion.
- Existing Music/Spotify querying remains a fallback for development builds without the bundled adapter. Ended sessions clear artwork and controls; helper failure disables transport and refresh can restart it.

## Verification

Native Swift build and signed app launch passed. CUA verified nested folder rows, the toggle at the top of the compact rail, and a relative Markdown link opening a second document tab in the running app. WebKit checks cover editing-mode link resolution/source preservation and nine Mermaid regressions. Swift tests include synthetic browser artwork/session termination in addition to existing persistence, geometry, and player tests.

The bundled adapter successfully ran a read-only system query; macOS returned no active media session at verification time. Live YouTube artwork and actual previous/next behavior are therefore not yet verified. Browser coverage depends on macOS Media Session participation and private MediaRemote compatibility, not a guarantee that every browser/site exposes metadata or supports skipping. No microphone recording or browser-history inspection is used. Release notarization and cross-version/hardware checks remain open.
