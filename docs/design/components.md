# SwiftUI component map

## Composition rules

Build reusable primitives in `CiderUI`, feature composition in `Features`, and native bridges in `CiderPlatform`. A component receives immutable view data and semantic actions; it does not discover services from global singletons. Use `@State` for local control state, bindings for owned values, explicit injected `@Observable` references for scene models, and environment only for genuinely shared dependencies.

| Component | Inputs / actions | Native responsibility |
| --- | --- | --- |
| WorkspaceShell | scene selection, visible columns | `NavigationSplitView`, native toolbar, commands |
| WorkspaceSidebar / SidebarSection / SidebarItem | folders, navigation counts, selection, compact mode | Inset rounded material surface or compact rail; shared selection treatment, folder disclosure, and nested note rows |
| AttentionRow | reason, status, age, feature, open action | Small selectable row; accessible full label |
| AttentionDetail | latest reply excerpt, links, verification, capabilities | Evidence-first detail; lazy transcript expansion |
| FeaturePhaseHeader | feature/phase, declared gate, lane counts | Clear hierarchy; no inferred percent |
| LaneRow | run summaries, dependencies, worktree, gate | Expand to timeline/history; stable IDs |
| TaskRow / TaskSection / TaskDetail | task snapshots, complete/edit/reorder | Shared day/calendar agenda rows, completed disclosure and rescheduling |
| TaskComposer | owned draft, planned day, submit/cancel | One component in day view, toolbar capture, and notch; native text field and keyboard submit |
| DateNavigator / WeekStrip / MonthCalendar / CalendarDayCell | selected day, visible month, locale, task summaries | Sidebar arrows/reset and list/calendar selection share state; real calendar arithmetic |
| QuickCaptureSurface | task/note draft, origin and presentation | Toolbar popover or native capture panel; focus and draft preservation |
| IconAction / CiderActionStyle | SF Symbol, semantic label/help, emphasis, action, enabled state | Shared rounded shape, warm tint, soft elevation, pressed/disabled behavior; native tooltip, VoiceOver and keyboard/menu equivalent |
| WorkspaceBackdrop | ember tokens and accessibility settings | Static warm gradient inside the app; works with native chrome materials |
| DocumentToolbar | title, save state, outline/source actions | Commands route to active document via focused values |
| DocumentPage / WritingStatus | document session, editor focus, word count, capture origin | Open writing plane, title/body placeholders, unobtrusive editing feedback; shared by new and existing notes |
| FrontmatterHeader | parsed properties, raw slice, edit actions | SwiftUI property layout; raw-YAML fallback |
| MarkdownEditorHost | document ID, revision, body, theme | One `NSViewRepresentable`/coordinator wrapping WKWebView |
| AssetFigure | thumbnail, alt text, metadata, annotation action | Lazy image sizing; no original decode in a list row |
| AnnotationCanvas | image ID, marks, selection | SwiftUI Canvas/native drawing; normalized coordinates |
| VerificationChecklist | check states, tested revision, record action | Human outcome is separate from agent reports |
| FeedbackComposer | selected findings, files, destination | Preview, copy/export, supported send action |
| UsageRing / UsageWindowRow | optional usage, units, reset, freshness | Empty/unknown ring and text alternatives |
| CiderPillPicker | label, options, selection binding, compact size | Shared capsule track and quiet warm selection for HUD tabs and Used/Remaining; native buttons, selected accessibility traits and solid Reduce Transparency fallback |
| NotchCompactContent | tiny attention/activity/usage snapshot | Hardware-safe wings/edge rail |
| NotchExpandedContent | tab, top items, actions | Compact SwiftUI hierarchy, no editor process |
| NotchShape | edge, exclusion, expansion progress | Geometry-only shape, separate interaction mask |
| DisplayPlacementPicker | display role, edge, alignment/offset | Native settings preview; no focus-based anchoring |
| IntegrationRow | connection/capabilities, setup/open actions | Distinguish observed, estimated, unsupported |

## Component states

The accepted task/calendar and capture behavior is in [tasks and capture](tasks-and-capture.md). Native transparency, Liquid Glass grouping and fallbacks are in [materials](materials.md). These apply to the Swift app, not only to the browser illustration. Framework/storage/prototype implementation language belongs in documentation, not the product interface.

The additional sidebar reference supplied during Phase 00 informs two modes: an inset rounded source list with groups/folders and nested notes, and a compact icon rail with a contextual section. Preserve explicit keyboard labels, selected document and folder disclosure while toggling; expose this as a normal toolbar/sidebar action. Settings and capture controls anchor the bottom. Do not adopt the reference's CRM entities, green credit meter, or profile identity. The latest [writing/sidebar contract](writing-and-sidebar.md) supersedes the earlier flat strip and input-style note outline.

Every async surface designs loading, useful content, empty, stale, error/recovery, and disconnected states explicitly. Local components do not show provider spinners when offline. Save-state text is `Saved`, `Saving…`, `Unsaved`, or a specific recovery action. A code/diagram failure stays local to its block.

Use native `Button`, `Toggle`, `Picker`, `List`, `Table`, `.inspector`, `.searchable`, `Menu`, and `Commands` first. Customize styles with semantic tokens. Keep native control focus indicators, menu semantics, tooltips and keyboard alternatives. The user explicitly requested no input-style rectangle around the document: show its caret and editing state while preserving text navigation and accessibility. Avoid custom gestures that intercept selection/scrolling or window dragging over controls.

## File responsibilities

One primary component/type per Swift file. Small tightly related styles can share a file; unrelated services and models cannot. Root views describe composition only. Extract subviews that own a meaningful visual or update boundary, not every `Text` into its own wrapper. Place expensive computed filtering/sorting in memoized projections, not repeated `body` evaluation.

No formatter allocation, image decoding, SQL/network access, file enumeration, or process queries in `body`. Usage clocks update only their label views. No WebKit view gets rebuilt because an agent status badge changed. Use identifiers/revisions to avoid feeding a model update back into the editor as a text replacement.

## Preview gallery and checks

Phase 01 creates a fixture gallery for all listed states, including long titles, zero/missing quota, 100% usage, Unicode paths, narrow window width, large text, reduced motion/transparency, and disconnected folders. UI fixtures use deterministic times/IDs. Snapshot checks focus on hierarchy, clipping, focus and status distinctions; integration tests verify domain behavior separately.
