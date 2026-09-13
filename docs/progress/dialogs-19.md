# Consistent app dialogs

The user's screenshot showed default gray plugin sheets that did not match Cider. Added a shared black/ember dialog shell, warm capsule controls, readable inset detail panels and icon/title headings. Applied it to plugin and observer setup, task details/editing/capture/linking, note connections/attachment, checkpoint preview, errors, delete confirmation and note renaming. System file pickers remain system-owned.

Renaming now presents a SwiftUI sheet from the notes model rather than a blocking NSAlert. It retains the existing rename callback and file/connection behavior. Notices and destructive confirmations share the dialog components; Escape cancels, acknowledgement supports Return, and destructive confirmation does not gain an accidental Return action. Busy install sheets retain dismissal/interaction protection.

All 154 existing Swift tests passed. A native offscreen synthetic rendering of the shared components was generated and visually inspected at `output/qa/dialogs.png` using `script/verification/DialogRender.swift`. It verifies the surface, typography, control contrast and layout without CUA. It is a component preview, not a capture of every live dialog; live keyboard/focus and nested-presentation acceptance remain unverified.

The final native rebuild/relaunch and strict deep signature validation passed.
