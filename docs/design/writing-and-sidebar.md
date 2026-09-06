# Writing surface, controls, and sidebar

Accepted refinement, September 6, 2026. Applies to the canvas and the future native app. This supersedes the flat full-height sidebar strip and input-style note focus outline in the original preview.

## Writing surface

- New note opens a large, open document page. Use the same `DocumentPage` and editor session as an existing note, with room to keep writing rather than a boxed entry field.
- Title and paragraphs share the reading column. Empty placeholders are `Untitled` and `Start writing…`; neither is document content. A new note starts empty. Do not inject a greeting or an empty heading into a saved file.
- A bright caret and small `Editing` indicator show focus. No border, colored rectangle, rounded input wrapper, or inset shadow around the title/body. Toolbar and other controls retain keyboard focus rings.
- The canvas illustrates an editable title and body with Enter moving from the title to the body. The native editor owns one continuous Markdown document: headings stay in its source model, not a second SwiftUI text field whose updates prepend another heading. Do not couple a heading to frontmatter `title` or rename a file automatically.
- New-note actions open/focus the writing page and preserve an existing draft. A blank new draft focuses its title; pressing Enter continues into the body. Switching between a review and a draft retains title, body, selection where supported, and images.
- Pasted images and ordinary Markdown blocks remain inline document content. The canvas image/diagram examples are an interaction illustration; actual Vditor integration, IME, undo, serialization and file persistence remain Phase 01 gates.
- Use a content-driven page and a maximum 720 pt reading width, 34 pt title, 16 pt body, 1.65–1.75 line height. Let the native document scroll in its content area. There is no nested input-box scroll region.
- `WritingStatus` shows a quiet word count and editing state. A native save indicator reports actual persistence acknowledgements. The canvas must never claim a disk save.

## Shared controls

`IconAction` and `CiderActionStyle` centralize shape, tint, elevation, hover, pressed, disabled and accessibility states for workspace, editor, task capture and HUD actions. Navigation/content rows keep their own selection semantics.

Use a capsule for text actions and 12 pt continuous corners for icon actions; smaller date controls use 9 pt corners. Apply a warm translucent fill and soft shadow, with a subtle top highlight. Bright orange gradient is reserved for primary actions. Tooltips describe the action and every icon has an accessible name. Do not make decorative depth depend on a permanent animation.

Native glass buttons/materials own their shadow and translucency. Token shadows and control gradients are the non-glass fallback. Group nearby custom glass shapes once; do not blur each icon separately or add a second shadow to system elevation. The [material policy](materials.md) covers accessibility and verification.

## Sidebar

Use the reference's inset silhouette, restrained line icons, soft selected pills, and connected folder hierarchy. The default width is 212 pt with a 12 pt outer inset and 20 pt corners. The prototype reduces the width slightly in a narrow desktop composition; the native source list remains resizable.

The brand mark and workspace name sit at the top. Core navigation comes next; date arrows and return-to-today sit under Today. Workspace folders disclose nested note rows. Settings and quick capture anchor the bottom. Do not add unimplemented search, fake profile, CRM rows or credit meters just to resemble the reference.

The compact rail is 64 pt, retaining the active section, tooltips and all core actions. Folder expansion and document selection survive mode changes. At phone-sized canvas widths, core navigation becomes a compact icon row and date controls move into the day page. This canvas adaptation does not imply an iOS product.

## Ownership and verification

The scene owns navigation and selected document ID. `DocumentSession` owns text/revisions/draft state. `WorkspaceSidebar` receives lightweight folder/note snapshots and callbacks; it does not access files or create editor instances. `DocumentPage` hosts the single lazy `MarkdownEditorHost`; usage and task updates must not recreate it.

Verify focused empty and populated notes, title-to-body typing, note switching, image ownership, folder disclosure and rail toggling. Check long labels, large text, keyboard use, reduced motion/transparency and light/dark/busy backdrops. Report browser interaction checks separately from native builds and hardware/material validation.
