# Product and interaction model

## Organizing work

The hierarchy is Workspace → Feature → Phase → Lane. A lane can have several agent runs and several worktree revisions over time. Conversations can span phases, so associate individual run/turn references with lanes instead of forcing one conversation into one phase forever. Related notes, decisions, tasks, tests, and artifacts are linked entities.

Workspace means a saved collection of folders, not necessarily one Git root. A feature may span repositories. Store root identities separately from branches and worktrees; names alone are not stable identity.

## Inbox: what needs me now

Order unresolved approvals/input requests first, failures second, completed work awaiting tests third, and informational updates last. Age breaks ties. Allow explicit pin, snooze-until, dismiss, and filter-by-feature; show counts that match the same definition everywhere.

An item contains a concrete reason, feature/phase/lane, originating tool/run, last observed time, and the next useful action. Details show the latest relevant reply, plan/document links, worktree and revision, tests reported by the agent, and user verification separately. Long transcripts load on demand.

Reading an item marks it seen. It does not approve, resolve, or verify anything. A dismissed event remains in history. New evidence after dismissal can create a new item; repeated delivery of the same event cannot.

If a connector cannot answer an approval, show **Open in source app** or **Copy response**. The HUD must never suggest an approval was sent when it only opened a window.

## Features: track phases without reconstructing conversations

Each feature has a short outcome, repository links, current phase, upcoming gate, and ordered lane list. A phase can have a dependency DAG. Display declared plan progress separately from measured gate completion; prefer `3 of 5 lanes awaiting verification` to an invented percentage.

Import a folder of Markdown plans through a preview. Suggest feature/phase/lane IDs from filenames and frontmatter, then let the user correct them. Show unmatched runs and unresolved dependencies explicitly. Imported prose never automatically starts processes or sends instructions.

Worktree details include repository identity, absolute path, branch, base revision, observed head, and dirty state. Missing/deleted worktrees retain history and offer relinking. Parallel work with the same branch name in different repositories remains distinct.

## Today: a human-sized daily list

Add a task from the day list, toolbar quick capture, notch, note selection, inbox item, or Jira issue. Fields: title, state, optional due date, planned day/order, feature/lane link, optional issue link. A due date and an intention to work on a day are separate fields.

Browse dates with previous/next/reset controls beside Today in the sidebar, a week strip, or a month calendar. Use compact grouped task rows and an expandable completed section. List/calendar share selection and the same data. Quick task is a peer of Quick note; the notch supports adding and checking tasks directly. See [task and capture behavior](design/tasks-and-capture.md).

Support inbox/backlog, Today, in progress, waiting, completed. Drag to reorder or use keyboard commands. A local completion changes a Jira issue only if a supported explicit sync action is configured. Keep offline operations visible and retryable. No automatic daily rollover of unfinished tasks into done.

## Notes: writing and testing in one place

Open several folders in one workspace. Offer a folder tree, recent notes, tabs, document search, and an optional outline/metadata inspector. Default to a single live-rendering editor. Source mode is a deliberate escape hatch for unusual syntax; a side-by-side preview is optional.

Write a heading, type a list, paste a screenshot, and keep writing. Cider saves the image beside that note according to its asset policy and inserts a relative Markdown link. The user never needs to manually move the pasted file. Drag images from Finder and paste text/code as expected.

Show YAML frontmatter as a compact property header with raw YAML available. Preserve unknown keys, ordering/comments where untouched, scalars, arrays, and multiline values. Invalid YAML stays intact and offers raw editing; do not silently repair it.

Display fenced code with language, syntax highlighting, and copy action. Display Mermaid blocks in the editor with an accessible text/source alternative and edit-source affordance. Render errors affect that block, not the whole note.

Native global capture opens a small text/image capture panel. With no selected note, save into the selected workspace's Inbox folder; with no workspace, retain an explicit draft until a folder is chosen. Do not silently put final notes in a random temporary folder.

## Verification and feedback

1. Select work awaiting testing. Capture the exact run, worktree head, and plan.
2. Open verification checklist; run tests in the source tools, or explicitly invoke a configured command later.
3. Record pass/fail/blocked/skipped per check, with environment, command/steps and evidence.
4. Paste a UI/network/console screenshot or text. Add numbered pins, arrows, rectangles, and captions. Keep the original screenshot immutable.
5. Create a linked finding/task. Group findings into a Markdown feedback bundle with annotated image derivatives and reproduction steps.
6. Preview the destination and content. Send only via an established connector action; otherwise copy/export/open the source conversation.
7. A fix creates a new run/revision. Preserve earlier evidence and retest it. Mark the gate verified only when the human's required checks pass or an explicit waiver is recorded.

A test result belongs to the tested revision. Changing worktree head invalidates the current gate's passed status until the user revalidates the relevant scope.

## Usage

Show Codex, Claude Code, and Cursor with per-account, per-window usage; indicate **used** or **remaining** consistently. Details show reset time, source, and last update. Never label every bucket "monthly." Stale, signed-out, unsupported, and unavailable each have distinct text. Token/cost estimates for runs appear separately.

## HUD versus workspace

HUD actions should take seconds: scan attention, open a run, add or check a task, capture a note, glance at quota. Feature planning, long editing, annotation, test review, and integration setup open the normal workspace window. Everything has keyboard/menu access as well as a hover path.

## First run, interruptions, accessibility

Start with a normal welcome/workspace window and a visible menu-bar fallback. Choose folders, offer the default built-in notch, then opt into providers. Explain capabilities at setup. Local notes and tasks work without integrations.

Use labeled controls, VoiceOver summaries, sufficient contrast, reduced motion/transparency alternatives, and keyboard reachability. Notifications are deduplicated by meaningful state changes; quiet hours suppress banners without losing Inbox items. Capture/screenshot actions are user initiated. Screen recording and Accessibility permissions are requested only for the feature that actually uses them.
