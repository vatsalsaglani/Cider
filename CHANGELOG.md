# Changelog

All notable changes to Cider are documented here.

## [Unreleased]

## [0.0.1] - 2026-09-13

### Added

- Initial technical preview of the native Cider workspace, notch HUD, notes, tasks, and local agent activity companion.

### Distribution

- The macOS archive is ad-hoc signed for this early release. It is not notarized.

- Downloadable app ZIP includes a companion SHA-256 file for checking the download.

### Open Cider locally

After extracting the ZIP and moving **Cider.app** to **Applications**, if macOS blocks this early release, run the following in Terminal only if you trust this download:

```sh
xattr -dr com.apple.quarantine "/Applications/Cider.app"
```

Then open Cider from Applications. This removes the downloaded-file quarantine flag from Cider only; it does not sign or notarize the app.
