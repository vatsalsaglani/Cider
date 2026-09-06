# Tasks, dates, and quick capture

Accepted product direction from the user's Phase 00 review. This applies to the native Swift app as well as the canvas.

## A useful day view

Lead with the selected date, a small Today/Tomorrow/Yesterday label when applicable, and the count of open/completed tasks. Use a quiet seven-day strip, compact task composer, clear task titles, small project context, and a collapsible completed group. Avoid a large empty form or a tag pushed to the far edge of each row.

The Today sidebar entry has **previous day, next day, and return to today** icon controls. Show the selected date between the arrows. Keep the navigation label Today stable; the detail header always names the selected date. When the rail is compact or the preview is narrow, the same DateNavigator component appears in the detail header. The reset changes selection; it never moves tasks.

Switch between list and month calendar using icon controls. The calendar shows task density and a short title where space allows; selecting a date updates its agenda. Month arrows browse months independently. Avoid squeezing illegible event titles into small cells. Selecting an adjacent-month cell changes both selected date and visible month. Remember list/calendar choice per workspace.

## Three entry points, one task command

| Entry point | Default date | Behavior |
| --- | --- | --- |
| Day composer | Selected day | Enter or the submit icon adds the task and keeps focus for the next one |
| Quick task in toolbar | Selected day while viewing tasks; otherwise today | Compact capture surface with title and editable planned date; stays in the user's current context |
| Notch Today composer | Actual today | Adds/checks tasks directly; date does not follow an unrelated day being browsed in the workspace |

Show the resulting planned date before submission. Every native composer calls the same `TaskCommands.create(draft:)`. A successful transaction updates the day list, calendar count, sidebar projection, and notch. Disable duplicate submit while the same draft is committing; preserve the text if saving fails. Show a useful error and retry action.

A draft has its own identity and text. A provider event, task check, date change, or HUD refresh cannot clear a partially typed draft. Capturing a note and a task use distinct drafts. Quick capture is available through menu and configurable keyboard commands as well as icon buttons.

Select a task to edit its title, planned date, or linked context. Completing a task is reversible. Moving its planned date changes where it appears; it does not change its due date, mark it complete, or silently change a Jira issue. Include keyboard reorder and reschedule actions; drag is an enhancement.

## Date semantics and persistence

Use a `LocalDay` value with calendar identifier and year/month/day components for planned days. It is not a UTC midnight timestamp. Store due dates separately as either an all-day date or an instant with timezone. An optional `plannedDay` is the daily intention; unplanned tasks remain in backlog. Preserve explicit ordering per planned day.

Use Foundation `Calendar` addition and locale-aware formatting, not `86_400`-second arithmetic. Respect the user's first weekday and date format. Recompute the actual-today projection on day/timezone changes and wake; no per-row timer. Travel must not shift an explicitly planned all-day task merely because a UTC offset changed. Midnight does not mark unfinished work done or automatically reschedule it.

## Shared SwiftUI components

`TaskComposer`, `TaskRow`, `TaskSection`, `TaskDetail`, `DateNavigator`, `WeekStrip`, `MonthCalendar`, `CalendarDayCell`, and `QuickCaptureSurface` live in the task/UI feature boundary. `IconAction` is a shared primitive for toolbars and compact controls. Components consume value snapshots, bindings to the owning draft/selection, and semantic closures. They do not query providers or own separate task databases.

The scene owns `selectedDay`, `visibleMonth`, and `viewMode`. A shared task repository actor persists tasks; a `@MainActor @Observable` scene model publishes day/calendar snapshots. A separate small HUD projection subscribes to actual-today tasks. Cancel superseded month queries and reject stale responses by query generation. Index planned day/state; query the visible month interval rather than every task in history.

## Focus in the notch

Hover opens a passive HUD and never takes keyboard focus. Clicking its task field explicitly starts a native capture session. A key-capable child/utility panel occupies the reserved composer area so capture appears within the notch. The passive panel remains non-key. The capture session holds the expansion open while editing, preserves its draft on dismissal, and restores the prior app's focus after submit/cancel where macOS permits. It has no WebKit editor.

Gate this behavior on real hardware, including typing while the external display previously had focus. Document permission, full-screen, Spaces, and focus-restoration limitations instead of quietly converting every hover panel into a key window.

## Copy and controls

Product copy describes the user's work: “New task”, “Today”, “Task added”, “Image added”, “Usage updated”. Do not display framework names, persistence architecture, implementation milestones, “Local by default”, or prototype disclaimers inside the product. Explain simulation limits outside the canvas and in progress docs.

Actions use a relevant SF Symbol with `.help(...)` and `.accessibilityLabel(...)`; navigation, task content, dates, and picker options retain readable text. Hover tooltips are supplementary: keyboard/VoiceOver users get the same names and menu commands. The icon label is a semantic action, not its symbol name. Keep focus rings and 44 pt hit areas in touch/coarse-pointer contexts.

## Acceptance

Add from each entry point and verify one persisted task appears everywhere. Browse yesterday/tomorrow and reset; switch list/calendar, cross month/year boundaries and leap days; edit/reschedule/complete/reopen; restart and recover drafts. Test midnight, DST, timezone changes, first-weekday preference, empty days, long titles, save failure, and rapid duplicate submit. Verify keyboard focus, menu equivalents, tooltips, VoiceOver, reduced transparency, and every supported display placement.

The canvas exercises the interaction model with session-only sample data. It is not native calendar, persistence, or focus evidence.
