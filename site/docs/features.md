# Cider features

Cider brings daily tasks, local Markdown, agent activity, usage, relationships, and media controls into one macOS workspace. The main window is organized into **Today**, **Notes**, **Agents**, **Graph**, **Usage**, and **Settings**; the menu bar and notch keep the small, time-sensitive actions close at hand.

![Cider Graph](images/graph.png)

## Today and task capture

Today combines a selected-day agenda, week strip, and month calendar. Add tasks from the day composer, the sidebar’s quick task action, or the notch TODO tab. Edit titles and planned days, add descriptions, statuses, due dates, and acceptance criteria, then complete or reopen tasks with one click.

Task pages collect linked notes, contributor chats, and a durable activity timeline. Back and Forward navigation connects task, note, and graph pages while preserving in-progress task edits. See [Tasks](#/docs/tasks).

## Markdown notes and workspaces

Notes opens Markdown files from one or more chosen folders. It provides a nested folder tree, open note tabs, Finder actions, note rename, path copying, and a full writing surface. Markdown headings, lists, tables, code, Mermaid, links, YAML frontmatter, and pasted images are supported according to the file’s contents. Cider saves images beside the note and inserts relative links so the files remain useful elsewhere.

The editor keeps drafts visible when a file changes or a save fails. Notes, tabs, and folder expansion restore across relaunches. Read [Notes](#/docs/notes) for the complete workflow.

## Linked work and Graph

Attach notes and agent conversations to a task, or create a task from a note or chat. Note relationships can be labeled **Plan**, **Context**, or **Evidence**. A task can have multiple contributor chats, each identified by provider and session.

Graph displays tasks, notes, and chats as connected nodes. Choose **Workspace** for a broader view or **Local** for one- or two-hop connections around a selection. Search, filter by node type, task status, provider, active chats, completed work, or isolated items; drag nodes, zoom, pan, fit the graph, and inspect or open a selected connection. Markdown links between known notes also appear in the graph.

The task timeline stores reported responses, questions, resolved questions, and your own notes. Checkpoints are previews until you confirm their append to a selected Markdown note. Agent output is evidence for review; it does not complete a task or verify it.

## Agent activity

The **Agents** page has two tabs:

- **Activity** lists observed sessions with provider, chat name when available, workspace, execution state, attention state, recent response or question text, and expandable history. Filter by provider or search chat and workspace names. Open the original source app, reveal the workspace, copy a session ID, attach the chat to a task, or create a task from it.
- **Agents** manages optional connections. Cider shows the exact observer configuration change before applying it and keeps tracking separate from plugin installation.

Cider can observe Codex, Claude Code, and Cursor sessions after you connect each provider. It records bounded activity metadata and short response or question excerpts so you can see what needs attention. A source app must still be running with the same identity for **Open source app** to activate it; otherwise Cider explains why it cannot open that session.

The mascot reflects idle, working, needs-you, and reply-ready states. Attention stays separate from execution: a question or approval request can remain visible while an agent continues working, and a finished response is not a verification result. The compact notch can show a five-second response peek with a return action.

## Optional Cider workflow plugin

When connecting Codex or Claude Code, you can review and install the optional Cider plugin. It adds commands for reading saved task context and for explicitly requested task or note changes through the running Cider app. It can also link notes to tasks and save requested checkpoint/context work.

Tracking and plugin installation are separate. Removing a plugin does not remove Cider’s local marketplace files or your task and note data. Cursor has activity connection support but is not offered the Codex/Claude plugin step.

## Usage

Usage shows **Codex**, **Claude Code**, **Cursor & Grok Bot**, and **Grok Build** as separate provider cards. Switch between **Used** and **Remaining** views. Each reported window can include its label, account, source, last update, and reset information; unknown or unavailable values stay unknown rather than appearing as zero.

Cider refreshes usage when it starts, every ten minutes, and after fresh agent responses where supported. In Connection settings, Codex and Claude Code can use the existing agent sign-in or command line. Cursor usage comes from its dashboard connection and may include a reported Grok Bot allowance. Grok Build uses its own Grok Build sign-in. These usage connections are independent of which providers you connect for activity tracking.

## Now Playing

The notch’s **Now Playing** tab reads the current system media session, including Music and Spotify when macOS reports them. It can show artwork, title, artist, source, playback state, transport controls, and an animated playback indicator. Media controls are also available in the expanded notch without opening the workspace.

## Notch and menu bar

The notch HUD is anchored to the built-in MacBook display independently of which display has keyboard focus. Choose whether it appears, whether hover opens it, which edge it uses, and its position along that edge in **Settings**. Pin the expanded HUD when you want it to remain open.

The collapsed HUD shows the Cider mascot plus compact agent and task counts. Expand it for Agents, TODO, Now Playing, or Usage. **Open Cider** takes you to the full workspace. The menu-bar item remains available as a fallback to open Cider or toggle the notch.

## Command-line access

Cider bundles a `cider` command for scripts and agent workflows. Read commands work with Cider closed, including task, activity, context, folder, and note reads. Task and note writes go through the running Cider app and require the current task revision or saved note hash, which protects drafts from stale replacements.

The CLI can create and update tasks, complete or reopen them, add timeline notes, create or replace/append Markdown notes, and link a note to a task. It never starts agents, approves tools, or treats an agent response as verification.

## Settings and persistence

Settings currently focuses on notch display and placement. Cider keeps tasks and linked-work records in its workspace store and keeps Markdown text in the selected files. Saved task edits, notes, linked relationships, open note tabs, folder expansion, selected notes, and notch preferences are restored when the app restarts.

## Accessibility and motion

Controls have readable labels and menu equivalents for compact icon actions. The mascot and notch motion respond to Reduce Motion; when reduced motion is enabled, the HUD uses a still presentation while preserving its information and controls.
