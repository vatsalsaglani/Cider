# Native materials and the ember background

The user explicitly requested a visible gradient inside the app and macOS transparency/Liquid Glass. Treat both as native product requirements.

## Surface policy

| Surface | Native treatment |
| --- | --- |
| Workspace backdrop | Static ember/brown gradient concentrated near the top and fading into the charcoal content background |
| Sidebar and normal toolbar | Standard `NavigationSplitView` and toolbar materials; inset rounded sidebar silhouette with source-list semantics; let the system provide the glass treatment |
| Compact quick actions and date controls | Native toolbar groups first; shared custom glass container only when needed |
| Quick task/note capture | Native popover/utility surface with legible material and explicit focus ownership |
| Notes, code, dense task content | Readable dark content plane; no repeated blur per row or code block |
| Camera-attached HUD | Black exterior to blend with the housing; small material-backed action groups may sit inside |

The warm backdrop is visible within the content header and through system chrome. Do not paint an opaque custom sidebar over the system material to reproduce a browser screenshot. Decorative content may use `backgroundExtensionEffect()` where appropriate to extend behind adjacent safe-area chrome; confirm geometry with the native split view. The user's dark palette remains the app's appearance direction.

For custom controls use `glassEffect(_:in:)`, native glass button styles, and one nearby `GlassEffectContainer` for related shapes. Use a local namespace and stable `glassEffectID` only for meaningful morphing transitions. The user requested rounded, tinted, softly shadowed actions: use subtle warm tint for quiet actions and stronger tint for primary/selected actions. Let native glass own refraction and elevation; do not stack token shadows or a second glass effect on a system toolbar button. A shared fallback style uses the control tokens when system glass is unavailable or transparency is reduced. These APIs and grouping behavior are described in Apple's [Liquid Glass guide](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

`NSVisualEffectView` is a narrow fallback for an AppKit-owned surface when SwiftUI's standard material cannot satisfy it. It is not a reason to rebuild every SwiftUI control. Do not substitute similarly named visionOS-only effects for macOS APIs.

## Tokens and fallbacks

The [token file](../../design/tokens.json) owns ember backdrop colors, alpha intentions, and solid accessibility fallbacks. Native material opacity and blur are system-managed; CSS blur radius is an illustration, not a value to hardcode into native glass. The canvas approximates transparency over its own backdrop and cannot reproduce macOS wallpaper refraction.

Reduce Transparency uses solid dark fallback surfaces. Increase Contrast preserves visible selection/focus and legible text across the gradient. Reduce Motion removes morphing/travel while retaining state changes. Check resolved materials over light, dark, and busy wallpapers as well as the app's own background; a token contrast calculation alone cannot validate glass.

## Resource and implementation ownership

`WorkspaceBackdrop` is a lightweight static SwiftUI gradient, not a raster screenshot or perpetual shader. `IconAction` keeps icon/label/help/disabled behavior consistent. `QuickCaptureSurface` composes the shared task or note draft with the native presentation. The workspace root handles scene structure, while the platform layer owns any utility panel. Do not create a separate expensive material layer for each calendar cell or task row.

Measure compositor/GPU cost and frame timing with materials enabled and reduced transparency before accepting the resource budget. Do not claim native Liquid Glass or memory performance based on the HTML canvas.
