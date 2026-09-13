# Cider task workspace — design comparison

Visual studies: [options.html](options.html). These are design mockups, not implemented app behavior.

## Requirements

Tasks open in the main workspace. A task → linked note → Back/Forward trip preserves unfinished work and location. Keep the native black/ember style, inset sidebar, and shared icon controls. Remove duplicate titles, scattered controls, fixed blank editor space, and oversized settings-style sections. Existing task persistence and document ownership remain authoritative.

## 1. Document-first — recommended

One editable title; status, planned date and optional due date directly beneath it. Content-sized description, acceptance criteria and linked notes share a 720-point reading column. Chats and recent activity follow below with progressive disclosure. Note rows open with one click; detach and context-copy actions belong in menus. A stable workspace header owns Back/Forward.

```swift
enum WorkPage { case today, task(UUID), note(UUID) }
@MainActor final class WorkNavigator {
    var page: WorkPage { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    func open(_ page: WorkPage)
    func goBack()
    func goForward()
}
// A note row opens a destination; it does not dismiss a sheet.
navigation.open(.note(noteID))
```

The navigator hides bounded history, branching, missing destinations and restoration. Task and document sessions retain drafts independently. Navigation is not a save acknowledgement. Scroll/focus restoration would need implementation; current task history only preserves draft and selected tab.

This is the simplest caller interface and the strongest fit for the common writing workflow. Long activity or chat collections need collapsed previews. Avoid flattening every historical event into the document.

## 2. Optional properties inspector

Main canvas contains one title, description, criteria and activity. A 264-point inspector owns status, dates, notes and chats. Opening a linked note replaces the main canvas while the originating task remains in the inspector. At narrower widths, details become a collapsible inline section.

```swift
enum TaskCanvas { case task(UUID), note(UUID, originatingTask: UUID) }
@MainActor final class TaskWorkspaceSession {
    var canvas: TaskCanvas { get }
    var inspectorVisible: Bool
    func open(_ canvas: TaskCanvas)
    func moveHistory(_ direction: HistoryDirection)
}
session.open(.note(noteID, originatingTask: taskID))
```

The session hides pinned task context, draft lifetime, history and document reuse. This offers the most flexibility for ongoing work with multiple references. It creates more visual structure, consumes writing width and requires clear rules for when the inspector follows the note versus its originating task.

## 3. Persistent task browser

A resizable task list stays between the app rail and task/note detail. The selected task remains highlighted while reading its linked note. Breadcrumbs return directly to the task; Back/Forward remains in a fixed detail header. Collapse the task list at narrower widths.

```swift
enum TaskWorkspaceCommand {
    case selectTask(UUID), openNote(UUID, from: UUID), showTab(TaskDetailTab)
    case back, forward
}
@MainActor final class TaskWorkspace {
    var presentation: TaskWorkspacePresentation { get }
    func send(_ command: TaskWorkspaceCommand)
    func draft(for taskID: UUID) -> TaskDraft
}
workspace.send(.openNote(noteID, from: taskID))
workspace.send(.back)
```

The small command interface hides list selection, history, tab restoration and stable drafts. It is specialized for rapid switching among TODOs. It uses horizontal space efficiently for task management but leaves less room for note writing. The command enum is more extensible, but a smaller method count alone does not make it simpler: callers must understand more commands and context rules.

## Synthesis

Use option 1's document hierarchy and typed navigator. Borrow option 3's explicit parent-task breadcrumb when arriving at a linked note. Keep session ownership separate from history, as in all three designs. Avoid an always-visible inspector or task list until the user chooses that workflow. All layouts require native verification at compact and wide widths, long titles, empty descriptions, multiple linked notes and Reduce Motion.

The proposed implementation is not part of this design pass. The installed skill explicitly says: “Don't implement - this is purely about interface shape”. The user's current request is to use it to design the update; this artifact completes that design stage and provides a concrete choice before implementation.

## Skill provenance

`design-an-interface` installed at `/Users/vatsalsaglani/.codex/skills/design-an-interface` from `mattpocock/skills`, revision `e7f0b58a4b8ad0764d9478b069fe6e48b99c320f`. The requested npx installer failed because the shell runs Node 22.0.0 while the package requires >=22.20.0. Codex's GitHub installer succeeded using the historical revision, since the skill is absent from the current tree. Three design-only agents independently explored the alternatives; no native app files were changed in this pass.
