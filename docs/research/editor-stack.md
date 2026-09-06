# Editor decision and evidence

Decision accepted by the user, 2026-09-06: **SwiftUI app with one lazy WebKit editor**. Candidate editor: Vditor. This selects the boundary; production acceptance still depends on the spike below.

## Why this package

Vditor implements WYSIWYG, instant rendering, code highlighting, and Mermaid rendering in one editor stack. Use **instant rendering** by default, with a quiet contextual toolbar and optional source mode. It covers the requested single editing surface without treating a display-only SwiftUI Markdown renderer as an editor.

Source inspected at [`4535ffb0c6b70809a0d5bcb477d9568e297ae83f`](https://github.com/Vanessa219/vditor/tree/4535ffb0c6b70809a0d5bcb477d9568e297ae83f). The source manifest says `4.0.0`; this is an inspected development revision, not a claim about the latest published release. Freeze a tested release/commit and its complete renderer assets in Phase 01.

| Candidate | Editing / rendering | Mermaid | Decision |
| --- | --- | --- | --- |
| Vditor | WYSIWYG, IR and source/split modes; highlighting; paste extension points | Built-in renderer | Selected for spike; embed only the editor |
| SwiftMarkdownEngine | Native AppKit/TextKit 2 live editor, SwiftUI wrapper; images and optional highlighting | No Mermaid implementation found in inspected README/Sources | Native alternative if the selected editor fails feasibility; would require custom diagram support |
| Textual | Native SwiftUI rich text/Markdown rendering | Not established as a complete Mermaid editing solution in reviewed docs | Optional compact read-only excerpts later, not the main editor |
| MarkdownUI | SwiftUI Markdown rendering | Does not establish requested editing flow | Maintenance-mode renderer; do not choose for new rich editing |

Sources: [Vditor README](https://github.com/Vanessa219/vditor/blob/4535ffb0c6b70809a0d5bcb477d9568e297ae83f/README_en_US.md), [native editor README](https://github.com/nodes-app/swift-markdown-engine/blob/08ff3c07b198ed639f595d0279ebac62c0410bc7/README.md), [Textual](https://github.com/gonzalezreal/textual), [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui). Textual/MarkdownUI were documentation inspections, not compiled evaluations.

## What comes built in, and what Cider must implement

Vditor owns typing/rendering and Markdown conversion. Cider owns local files, workspace roots, asset paths, native paste interception, autosave/conflicts, frontmatter presentation, annotation, shortcuts, and the association with tests/runs. The package's upload handler is an extension point, not a ready-made local filesystem transaction. See [upload type](https://github.com/Vanessa219/vditor/blob/4535ffb0c6b70809a0d5bcb477d9568e297ae83f/types/index.d.ts#L385-L435).

A native property header will keep raw frontmatter outside body serialization. The [document contract](../contracts/documents.md) defines source preservation and revision-safe saves. Rich-edit normalization must be tested rather than hidden.

## Offline renderer and security configuration

Vditor defaults to a CDN in [`constants.ts`](https://github.com/Vanessa219/vditor/blob/4535ffb0c6b70809a0d5bcb477d9568e297ae83f/src/ts/constants.ts#L51). Bundle the editor, Lute conversion runtime, selected languages/themes, Mermaid, highlighting, and any required fonts/assets locally. Set every loader path to the app's local resource scheme. Test with networking disabled; a local index file alone does not make the editor offline.

The inspected [`mermaidRender.ts`](https://github.com/Vanessa219/vditor/blob/4535ffb0c6b70809a0d5bcb477d9568e297ae83f/src/ts/markdown/mermaidRender.ts#L11-L67) re-initializes Mermaid with `securityLevel: "loose"` and HTML labels. Do not assume setting strict once before Vditor loads will survive that call. Phase 01 must use a documented custom-render override or a small tracked patch that sets strict configuration for every render, disables HTML labels/click actions, and preserves source on errors. Record patch provenance and test upgrades.

Use a restrictive content policy, sanitize imported HTML/SVG, block network subresources and navigation by default, allow user-initiated external links through native URL handling, and keep the native message protocol allowlisted. Remote images require an explicit load/import action. Reject Mermaid directives that weaken security; cap graph size and rendering time so one graph cannot freeze the editor. Rendered diagrams retain accessible source/text alternatives.

## Memory and native interaction

Construct the editor when a note is opened, retain one active surface for the MVP, serialize before switching, and release after inactivity when safe. Retain text/selection/undo policy explicitly; destroying a WebView must not discard unsaved changes. Measure web-content process memory together with the app. Avoid a WebView per note, per diagram, or per agent reply.

Use native menus for editing/find, native pasteboard import, and a SwiftUI file tree/inspector. Test IME, undo/redo, selection, accessibility, spellcheck, copy/paste and keyboard focus directly in WKWebView; browser behavior is not proof of native behavior.

## Mandatory spike fixture

One document with YAML comments, nested properties, multiline values, headings, checked tasks, GFM tables, links with spaces/Unicode, Swift/TypeScript/Python/JSON code, inline images, flowchart/sequence/Gantt Mermaid, and an unknown fenced language/block. Test 20k characters plus five 1920×1080 screenshots; additionally test a 1 MiB long document and malformed/oversized diagrams.

Pass: no-op bytes unchanged; supported edits semantically round-trip; frontmatter untouched bytes remain exact; unknown content preserved or explicitly routed to source mode; repeat image paste saves unique relative assets; local save/reopen works; undo and IME are stable; diagrams/highlighting work fully offline; malicious HTML/link/diagram fixtures cannot trigger network/native actions; VoiceOver can reach content; memory/input targets are measured.

If a gate fails, first fix the bounded bridge/package configuration. If preserving edits requires a deep fork or unacceptable resource use, record the failure and revisit the native alternative with the user. Do not silently downgrade to preview-only or remove Mermaid.

## Dependency provenance

Vditor declares [MIT](https://github.com/Vanessa219/vditor/blob/4535ffb0c6b70809a0d5bcb477d9568e297ae83f/LICENSE). SwiftMarkdownEngine declares [Apache-2.0](https://github.com/nodes-app/swift-markdown-engine/blob/08ff3c07b198ed639f595d0279ebac62c0410bc7/LICENSE) and separates optional code/LaTeX bridges; its code highlighting bridge uses JavaScriptCore, so native text views alone do not imply zero JavaScript. Preserve transitive notices if shipped. Neither editor was built or benchmarked in Phase 00.

