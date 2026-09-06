# Document, asset, and annotation contract

## Source of truth

UTF-8 Markdown on disk is the portable source. A Swift `DocumentSession` owns the loaded text, base disk hash, edit revision, unsaved changes, and save state. The WebKit editor is a projection with a versioned edit channel. The database stores note identity/links/search metadata, not the only copy of text.

No-op open/save preserves bytes. For supported body syntax, edits must preserve semantic round-trip and unrelated content. Rich editors may normalize Markdown; Phase 01 must quantify this on fixtures. Unsupported blocks stay source-preserved or switch the affected document to source mode with a visible reason. Never silently discard a block or normalize away unknown frontmatter.

## Workspace and file layout

```text
workspace-folder/
  reviews/
    phase-03-review.md
    phase-03-review.assets/
      20260906-093012-a1b2c3.png
      20260906-093012-a1b2c3.annotations.json
      20260906-093012-a1b2c3-marked.png
  plans/
    phase-03.md
```

Default asset path: `./{document-stem}.assets/`. Preference precedence: per-file override → workspace default → application default. Per-file overrides live in Cider metadata by default; users can opt into portable frontmatter keys under a `cider` namespace. Do not inject frontmatter into arbitrary existing notes without an explicit setting/action.

Template expansion supports `{document-stem}` and `{document-id}` only initially. Resolve paths against the document directory, standardize/canonicalize, and validate they remain inside an authorized folder. An explicitly selected external asset folder can be supported with its own access grant, but warn that exported notes may not be portable. Relative Markdown paths are URL-encoded for spaces and reserved characters, without modifying actual filenames unnecessarily.

## Paste transaction

1. Intercept an actual paste/drop event, inspect the pasteboard through native APIs, and prefer original supported image bytes; encode TIFF/bitmap screenshots as PNG. Text/code paste remains text/code.
2. Validate type, dimensions, and configured byte/pixel limits. Default proposed ceiling: 25 MiB or 40 megapixels; larger inputs offer resize/import rather than failing invisibly. Keep original data if the user chooses an optimized derivative.
3. Reserve a collision-resistant filename using timestamp + random ID. Write in the destination directory to a temporary sibling, flush as appropriate, then rename atomically.
4. Insert a relative `![Description](phase-03-review.assets/name.png)` at the captured document/revision/selection anchor through the editor bridge.
5. Record source edit and asset insertion as one user undo group. Save the Markdown with the normal coordinated writer. If insertion/save fails, retain the original text and an explicit recoverable pending asset; reconcile the journal after a crash.

Two filesystem files cannot become atomic through a single rename. Persist a small journal for the asset-write/link-save pair and test crash points. Never delete the original pasted asset on undo immediately: another note or undo history may reference it. Offer orphan cleanup with a preview after a retention period.

If the user pastes into an untitled note, keep an explicit recoverable draft and stage assets in the app's draft store. Once a folder/name is selected, move/copy the group with conflict checks and rewrite links. Do not show a final save state before the target commit succeeds.

## Save and external edits

Debounce autosave approximately 500 ms after edits, with explicit Cmd-S and a bounded flush on close/quit. Do not save an intermediate IME composition. Editor acknowledgement includes the revision whose serialization is complete; the save cannot assume the latest keystroke has crossed the bridge.

Use coordinated reads/writes and compare base hash/revision before replacement. Watch parent folders so atomic replacement by another editor is detected. If the disk changed and Cider is clean, reload with selection preservation. If both changed, retain both versions and show merge/reload/save-copy choices. Read-only, permission loss, offline volumes, disk-full, and failed writes retain the dirty draft and explain recovery.

App-managed rename/move previews the note/asset paths and link changes. Keep asset folders stable on a simple note rename by default, which leaves existing links valid; offer grouped rename explicitly. External moves relink through file identity/bookmarks when possible, otherwise ask for the missing folder. Never blindly rewrite other notes by matching filename text.

## Frontmatter

Recognize a leading YAML block, retain its raw slice and line endings, and render properties in a native header. The Markdown body crosses the editor boundary separately; Swift joins the preserved frontmatter and updated body at save.

An untouched header remains byte-identical. Editing a supported field uses a source-aware patch; if comments/anchors/custom tags make that unsafe, edit raw YAML instead. Yams may parse values, but re-serializing a dictionary is not a comment/order-preserving round trip. Invalid YAML remains visible and intact. Keep document title/headings separate from optional `title` metadata unless the user chooses a linkage.

## WebKit protocol

Native → editor: `loadDocument(documentID, revision, body, theme)`, `insertAsset(requestID, selectionToken, relativeURL, alt)`, `requestSerialize(requestID, revision)`, `setMode`, `setSelection`.

Editor → native: `ready(protocolVersion)`, `changed(documentID, baseRevision, editRevision)`, `serialized(requestID, documentID, editRevision, body)`, `assetPasteRequested(requestID, selectionToken)`, `selectionChanged`, `renderError(blockID, category)`.

Validate IDs, revision monotonicity, JSON shape, byte limits, and allowed action names. Reject messages from wrong frames/origins. Use structured arguments such as `callAsyncJavaScript` arguments rather than interpolating note text into executable JavaScript. Prevent native refreshes from feeding back as user edits. Keep message handlers weak or remove them on teardown.

An `AssetResolver` maps opaque document/asset IDs in the WebKit resource scheme to authorized files. It rejects path traversal, unauthorized symlinks and arbitrary filesystem access. Links stay relative in saved Markdown; the runtime resolver need not expose absolute paths to scripts.

## Annotations and feedback

Original image bytes and SHA-256 are immutable. Store pins/rectangles/arrows/captions with normalized coordinates, original image dimensions, orientation, and schema version in a sidecar. Generate an annotated PNG derivative through native drawing for portable feedback; original and derivative have distinct paths.

Feedback export includes feature/phase/lane/run IDs, tested revision, steps, expected/observed behavior, relevant console/network text, and relative annotated images. Bundle preview shows the destination and included files. No silent upload of a workspace or surrounding screenshots. Remove a bundle only through a visible user file action.

