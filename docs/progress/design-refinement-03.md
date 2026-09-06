# Design refinement 03 — writing, controls, sidebar

September 6, 2026. Scope remains the interactive prototype and native design contracts; no production Swift app was built.

## Result

- New notes open an empty document page with an editable title and large body, without a text-field frame. Placeholders are visual only; an untouched draft has empty source. Enter moves from the title to the body. A caret and quiet editing state replace the document outline.
- The sidebar follows the supplied concept through an inset rounded surface, warm selected pills, nested review/draft rows, folder disclosure and an optional compact rail. Settings and capture sit at the bottom. Date controls retain the accepted behavior.
- Shared action controls have rounded shapes, warm tint, soft elevation and hover/pressed states across the workspace, editor, tasks and notch. Icons retain accessible names/tooltips. The ember backdrop remains inside the window.
- The token schema and native `DocumentPage`, `WorkspaceSidebar`, `IconAction` and `CiderActionStyle` contracts reflect the same requirements. Native glass owns its material and elevation; token shadows describe a fallback.

## Verification

Chrome 152.0.7977.82: 48 pane/width/theme layouts (1024, 736, 360 and 320 px, light/dark host preferences, reduced motion) had no horizontal overflow. Interactive checks passed for notes, title/body focus, draft preservation, folder disclosure, tasks, dates, all three task composers, calendar, attention, image import/annotation, usage illustration and HUD placement/hover/pin.

Focused empty-note screenshots were inspected along with the expanded sidebar, compact rail and review note. The final source cleanup was checked separately: empty source, no placeholder heading, source-to-draft toolbar reset, and the focused body at all four widths. JavaScript syntax and local documentation links were checked. See [machine-readable check record](design-refinement-03-checks.json).

Native build, system Liquid Glass/accessibility, hardware display behavior, real Vditor/Mermaid, filesystem persistence, live integrations and memory/CPU/energy measurements remain unrun. Browser shadows and blur do not establish native material fidelity or resource use.

## Durable handoff

Start with [writing/sidebar requirements](../design/writing-and-sidebar.md), [component map](../design/components.md) and [tokens](../../design/tokens.json). Edit [prototype sources](../../design/prototype/README.md), then regenerate the canvas. Do not reintroduce the original full-height sidebar divider or orange input outline from older screenshots.
