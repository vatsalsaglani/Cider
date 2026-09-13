# Native dependency provenance

## Linked-work packaging

The linked-work store uses system SQLite via `CSQLite`; no graph engine or external service was added. SwiftPM product `cider-cli` avoids the case-insensitive collision with `Cider` and is packaged as `Contents/Helpers/cider`. The schema bundle belongs in `Contents/Resources/Cider_CiderData.bundle`; the portable skill is in `Contents/Resources/cider-workflow/`. Project-local installation is an explicit reviewed action and protects edited/unrelated files.

`script/build_and_run.sh --package` supports `CIDER_BUILD_SCRATCH` and `CIDER_PACKAGE_PATH` for independent bundle verification without quitting or launching the app. Read [verification evidence](../progress/linked-work-14.md) for tested artifacts and distribution limits.


## Editor

Vditor 4.0.0 from https://registry.npmjs.org/vditor/-/vditor-4.0.0.tgz.
Published integrity: sha512-JUeSmmNNxXaq4j29F6OZ/vLgyM/Wt/SpSK4o/gyrc02uTsS+iTeC0ofajxbW29WSJ4LFMec4nrywVul51PrLvg==.
Bundled dist is offline, including Lute, highlighting and Mermaid. Upstream license and bundled subcomponent licenses remain alongside the files. Local patch: Vditor's Mermaid securityLevel loose changed to strict in index.js and index.min.js. CSP permits only bundled cider-scheme scripts, styles and fetches; it denies external network, frames and objects. The readable index.js is the runtime entry point; its Mermaid adapter delegates to dist/cider-mermaid.js. Mermaid is loaded with the lazy editor, initialized once with the base theme plus Cider colors, and rendered through a serial queue. Preview replacement is observed, stale renders are discarded, and parse failures stay recoverable. No theme directives are inserted into Markdown. Theme API: https://mermaid.js.org/config/theming.html. Native bridge only accepts main-frame cider messages. Asset reads are canonicalized and restricted to image types under the selected note folder.

## Usage

CodexBar CLI v0.56.6 official release, bundled for the build architecture (arm64 or x86_64). The bootstrap downloads it only when absent and checks archive SHA-256 d41af4267c7074d240243df6759b23a6f005cbbbf9412bdebc6393db8c6885d4. The x86_64 archive SHA-256 is fde382eed39dd1788f11e4880a0ded3a2dba76303f70a9ebbe5bea8b8e96f2a4, verified against the official release metadata. App build requires and copies the helper and resource bundle into Contents/Helpers. No global installation. MIT license in CodexBar-LICENSE. CommandRunner uses argv, private temporary output, per-request deadlines and an output size limit. It never sends note content to providers.

Cider invokes `usage --provider <provider> --source <source> --format json --no-credits` through the bundled helper. Codex, Claude and Grok Build use explicit OAuth/CLI sources; Automatic tries OAuth then CLI without browser discovery. The separately enabled Cursor connection uses CodexBar's `auto` app/browser session ladder and includes its `cursor-grok-bot` named window when reported. No Cider-owned credential parsing or provider configuration writes were added. New Cursor and Grok Build usage toggles default off. Usage refreshes every ten minutes and after observed local response completions, with coalescing, independent failures, original observation timestamps and last-good readings. Requests have 45-second deadlines (75 for CLI), bounded output, cancellation and private temporary output. The helper path resolves only from the current app bundle. Only the arm64 package has been built locally.

Provider mapping follows the pinned [Cursor documentation](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/cursor.md), [Grok documentation](https://github.com/steipete/CodexBar/blob/v0.56.6/docs/grok.md), and [quota model](https://github.com/steipete/CodexBar/blob/v0.56.6/Sources/CodexBarCore/UsageFetcher.swift). Existing MIT attribution remains packaged. No upstream implementation code was copied. CodexBar is a usage source; its Bot allowance does not establish a live Bot lifecycle feed. See [expanded connections](../progress/notes-graph-providers-15.md).

Brand assets downloaded from https://raw.githubusercontent.com/steipete/CodexBar/main/docs/logos/claude.svg and codex.svg. These identify their providers and do not imply affiliation. Upstream MIT attribution retained; trademarks remain their owners'.

## App mark

Built-in image generation, 2026-09-06. Saved under Sources/CiderPlatform/Resources/branding/cider.png. Packaged ICNS derived for macOS icon sizes.

Prompt: Create a production macOS app icon for Cider, a calm personal workspace for notes, tasks and coding agents. A single distinctive abstract folded ribbon / paired interlocking rounded arches suggesting gathering thoughts, NOT a letter C and NOT fire. Bold simple silhouette readable at 20px. Warm orange to pale apricot gradient mark, centered on pure black rounded-square app tile, generous margins, subtle precision dimensional highlight, no text, no extra symbols. Square 1024x1024.

## Now playing

Music/iTunes and Spotify distributed player announcements remain the event source. A bounded, fixed AppleScript query on a serial utility queue retrieves an already-playing track at startup and refresh. It only queries running Music/Spotify apps, retains player-specific snapshots and discards stale query results after a new notification. It does not access the microphone or send playback commands. macOS may request Automation access; a denied request is reflected in the HUD. The purpose string is bundled in Info.plist. Browser playback is not supported. macOS system-wide MediaRemote access is private and is not used.

## System Now Playing adapter

- Source: https://github.com/ungive/mediaremote-adapter
- Pinned commit: `73f14ab1568371e6e3c44063f21c34c5e2712c4d`.
- License: BSD-3-Clause, copyright Jonas van den Berg; preserved in `Vendor/MediaRemoteAdapter/LICENSE` and the distributed Helpers directory.
- Vendored source: `Vendor/MediaRemoteAdapter/{src,include,bin}`. `script/build_media_helper.sh` compiles the Objective-C framework for the current build architecture.
- App bundles the framework and Perl entrypoint. System `/usr/bin/perl` loads the adapter to receive macOS MediaRemote state; no separate user install. This is a private system API compatibility boundary and requires revalidation on macOS updates.
- Only media metadata and explicit user transport commands cross the boundary; no browser credentials, page contents, or microphone audio.
