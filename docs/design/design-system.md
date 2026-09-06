# Cider design system

The visual direction is **warm precision**: black notch, charcoal working surfaces, warm-white text, a restrained ember gradient, and a few strong actions. No Qyrus branding, blue/teal branding, generic gradient dashboards, or decorative media controls.

Canonical values: [design/tokens.json](../../design/tokens.json). Concept artwork: [direction v1](../../design/concepts/cider-direction-v1.png). The exact [generation prompt](image-prompts.md) is preserved.

## Color roles

| Token | Value | Role |
| --- | --- | --- |
| background / notch | `#08090B` / `#000000` | Workspace / physical notch blend |
| surface / surfaceRaised | `#111214` / `#191A1D` | Reading and ordinary surfaces / selected utility content |
| surfaceHover / borderSubtle | `#242426` / `#303033` | Pointer state / decorative separators |
| textPrimary / textSecondary | `#F5F2ED` / `#A6A29B` | Content / secondary metadata |
| accentStart / accent / accentEnd | `#FF6A32` / `#FF8A3D` / `#FFB66B` | Ember gradient |
| textOnAccent | `#18100B` | Dark labels on filled accent buttons |
| accentWash | `#302018` | Subtle selection |
| focusRing | `#FFB66B` | Keyboard focus |
| success / warning / failure | `#D8D4CC` / `#FFB66B` / `#FF967A` | Always paired with icon and text |

Use orange for attention, selected navigation and the single primary action. Positive status stays neutral with a checkmark; reserve warm failure/warning colors for actual meaning. Provider identity comes from monochrome glyphs/text, not a different branding color per provider. Native traffic lights retain system colors.

Keep task and note content legible. The ember gradient also appears inside the app as a warm upper backdrop fading into charcoal and showing through system chrome; it is not confined to the notch or accent buttons. Use `textOnAccent` on bright controls. Separators are not the only indication of a focused or selected control.

## Typography and density

Use SF/system text and SF Mono/system monospaced fonts, including system fallbacks. App body 13 pt, secondary 11 pt minimum, section heading 15 pt, page heading 28 pt. The editor uses 16 pt body with 1.65 line-height and a comfortable 720 pt maximum reading column. Text settings can increase editor size independently of dense navigation.

Use 4/8/12/16/24/32/40 pt spacing. A single clear title, compact metadata, and folder hierarchy provide structure. Avoid a rounded card around every content row. Code, images and inspector summaries may use bounded surfaces. Prefer min sizes/content-driven layout to fixed text frames.

Sidebar variants follow the user's later reference: a 212 pt inset source-list surface with 20 pt corners, expanded labels, nested notes, and folder disclosure; or a 64 pt compact rail. Selection is a soft warm pill with an ember icon, without a stripe attached to the outer window edge. Settings and quick capture anchor the bottom. Use native sidebar materials and accessibility semantics. The rail must not depend on hover for essential actions. See [writing and sidebar refinement](writing-and-sidebar.md).

Action buttons use capsule shapes; square icon actions use 12 pt continuous corners (9 pt for small date controls), a gentle warm tint, and a soft elevation shadow. Control groups use 16 pt corners. Native system glass supplies material and elevation where available; token shadows describe the fallback, not an extra shadow layered over system glass. Tint quieter controls gently and reserve the bright gradient for primary actions.

Notes occupy a large open writing plane. The title and body have no input outline, enclosing border, or focus rectangle. An ember caret and a small editing indicator show where typing goes; action controls retain their native keyboard focus. Empty-title/body placeholders are presentation only and must not appear in saved Markdown. Native title size is 34 pt, with a 16 pt body and one 720 pt maximum reading column.

## Native SwiftUI mapping

Create semantic `CiderColor`, `CiderSpacing`, `CiderRadius`, `CiderType`, and `CiderMotion` names in `CiderUI/Tokens`. Generate or validate matching asset-catalog colors and editor CSS from the JSON during Phase 01; handwritten drift between native and WebKit is a release defect.

Example interface shape (illustrative, not compiled app code):

```swift
enum CiderType {
    static let body = Font.system(size: 13)
    static let code = Font.system(size: 12, design: .monospaced)
}

struct AttentionRow: View {
    let item: AttentionRowSnapshot
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            Label(item.title, systemImage: item.symbolName)
                .foregroundStyle(CiderColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityHint(item.nextActionDescription)
    }
}
```

SF Symbols are the native icon source: `tray`, `square.stack.3d.up`, `checklist`, `doc.text`, `chart.bar`, `gearshape`, `arrow.up.right.square`, `pin`, `exclamationmark.bubble`. Validate symbol availability in the selected SDK; labels must survive a missing glyph. No rasterized app text.

## Liquid Glass

Use macOS 26 native split-view sidebar, toolbar, popover, and control materials with dark appearance matching the chosen palette. Keep the camera-attached notch black. Use a single `GlassEffectContainer` for related custom floating controls where needed; do not paint custom opaque fills over native system chrome. Keep blur off repeated rows and the Markdown reading plane. Reduce Transparency produces solid surfaces. See [native material policy](materials.md) for API choices, ownership and verification.

Action controls use SF Symbols with native help text, accessible labels, and keyboard/menu equivalents. Navigation and content keep readable text. Product copy describes work and outcomes; framework names, storage architecture and development milestones are not interface labels. See [task/capture components](tasks-and-capture.md).

## Motion and feedback

Controls respond in 120 ms; HUD expands in roughly 220 ms after a configurable 250 ms dwell and collapses after 450 ms grace. Activity does not animate continuously. Numbers use monospaced digits when changing. Reduce Motion removes travel/spring; a small change in opacity or immediate update is enough.

## Accessibility and resizing

Maintain WCAG-style contrast goals of ≥4.5:1 for normal text and ≥3:1 for meaningful nontext affordances. Test actual resolved/material colors as well as token values. Keep text labels for status and quota units, native focus, keyboard menu paths, accessible annotation descriptions and Mermaid source alternatives. The app workspace supports resizable columns; collapse the inspector before truncating primary content. The canvas reflows down to narrow widths but is a desktop design preview.
