# Native UI, notes and connections — 2026-09-06

## Delivered

- Hidden native title bar with a custom drag region and small shared action controls. Translucent gradient-aware sidebar collapses to a rail; selection is shared and explicit.
- Centered task empty state, single main date navigation, new note/task actions.
- Notch uses an edge-attached outline with concave shoulders; hit testing uses the same path. Day arrows/reset update the task list and the destination day for capture. White content with orange accents replaces all-orange text.
- New folded-ribbon mark in workspace/notch/menu bar and packaged ICNS. Display name Cider; internal module/package identifiers remain Cider.
- Multiple persistent workspace folder selections, Markdown enumeration, creation, live Vditor editor, frontmatter display/preservation, offline code highlighting and Mermaid, autosave with disk comparison, recovered draft storage, image paste into per-note assets after native write acknowledgement. Notes remain ordinary Markdown files.
- Codex and Claude icons and provider cards, enabled-provider settings, helper discovery, explicit refresh, sign-in/CLI connection choice, usage windows/reset/freshness. Official checksum-verified CodexBar helper bundled for arm64, no global install.
- Passive Music/Spotify now-playing announcements displayed when received in the notch.

## Checks actually run

- Swift 6 build and real .app launch passed, including resource bundling and local ad-hoc signing.
- Eight tests passed: display origin/camera alignment; shoulder outline; DST date arithmetic; invalid date decode; snapshot persistence/corruption retention; byte-preserved CRLF frontmatter; subprocess deadline; missing quota remains missing.
- Native CUA inspected expanded and collapsed sidebar, notes UI and provider icons.
- Opened isolated `output/qa/native-notes/Editor-check.md`: verified bold heading, Swift syntax colors and rendered Mermaid nodes/edges offline. Typed a marker; disk save preserved frontmatter and code/diagram source.
- Codex live OAuth helper returned success with primary/secondary/tertiary windows. CLI strategy timed out. Claude OAuth returned credential-cache unavailable. Neither failure was represented as zero usage.

## Practical limits / remaining verification

- Physical camera seam, all edge placements, multi-monitor focus and notch capture still require hardware verification. The unavailable IMG_6018 attachment was not read; supplied screenshots guided the contour change.
- Now-playing is Music/Spotify announcement based: it updates on player changes. Universal/browser playback and initial playback-state queries are not implemented; no playback controls or automation permission are requested.
- Image paste native write/ack path implemented but not exercised with a real clipboard image this pass. Per-file asset-folder overrides, annotation UI and image transaction crash-injection tests remain outside this iteration.
- Notes retain dirty drafts and reject external-write conflicts; no merge UI, folder watcher, source-aware property editing, rename/move or large-workspace indexing yet. Rich editing can normalize Markdown body formatting; no-op opens preserve disk bytes.
- Resource/memory performance and release signing/notarization are not certified. Local ad-hoc signing only.

Dependency versions, licenses, helper checksum, icon prompt and security boundaries: [provenance](../implementation/dependencies.md).
