# Native route

- Read [architecture](../../../../docs/architecture.md) for target boundaries and ownership.
- UI work: [tokens](../../../../docs/design/design-system.md) and [components](../../../../docs/design/components.md).
- Note/sidebar refinement: [writing surface and controls](../../../../docs/design/writing-and-sidebar.md). New notes are open document pages; do not restore an input-style focus rectangle.
- Task UI: [dates and capture](../../../../docs/design/tasks-and-capture.md). Chrome: [native materials](../../../../docs/design/materials.md). Read these before reusing the canvas layout in SwiftUI.
- Window work: [notch behavior](../../../../docs/design/notch-behavior.md). Keep AppKit in the panel/display bridge.
- Editor work: [editor decision](../../../../docs/research/editor-stack.md) and [document contract](../../../../docs/contracts/documents.md).
- Read the relevant section of [verification](../../../../docs/verification.md) before choosing checks.

The Build macOS Apps skills are already available. Use swiftui-patterns, appkit-interop, window-management, and liquid-glass as appropriate. Use build-run-debug for an actual native scaffold and its Run-button contract; source inspection alone does not need a build.
