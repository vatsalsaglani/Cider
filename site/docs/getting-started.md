# Getting started with Cider

Cider is a macOS companion for tasks, Markdown notes, agent activity, usage, and music playback. It opens as a regular workspace window and can also stay available from the menu bar and your MacBook notch.

## Install Cider

Download the latest release from [Cider releases](https://github.com/vatsalsaglani/Cider/releases/latest). The current release is intended for Apple Silicon Macs running macOS 26 or later.

This is an early release and the app may be ad hoc signed rather than notarized. If macOS asks whether to open Cider, use the normal Finder **Open** action or the per-app approval shown in **System Settings → Privacy & Security**. Keep macOS security protections enabled; the approval is only for Cider.

## Choose a workspace

Open Cider and start in **Today**. To work with notes, open **Notes** and choose **Add folder**. Cider scans the selected folders for `.md` and `.markdown` files and keeps the folder tree, open tabs, and selected note across relaunches.

If you create a note before choosing a folder, Cider offers `~/Documents/Cider` as its default notes folder. You can add another folder later without moving the files already on disk.

## Add your first task

Use the task composer in **Today**, the quick task button in the sidebar, or **Add a task…** in the notch. Today’s page includes a week strip and a calendar view; use the date controls to plan work on another day. Click a task title to edit it, choose a planned day, and mark it complete with its check button. Completion is reversible.

Read the full task workflow in [Tasks](#/docs/tasks).

## Write a note

In **Notes**, select **New note**, type in the open writing surface, and let Cider save your changes. Use **⌘S** when you want to save immediately. Cider keeps Markdown on disk, including relative image links, and restores a recovered draft when a previous save was interrupted.

Read the editor and workspace guide in [Notes](#/docs/notes).

## Connect optional features

Open **Settings** to show or hide the notch, choose its edge, and set its position. Hovering the notch opens a glanceable HUD; clicking it opens tabs for **Agents**, **TODO**, **Now Playing**, and **Usage**.

Open **Agents → Agents** to review a proposed connection for Codex, Claude Code, or Cursor. Cider observes activity only after you approve the displayed configuration change. The optional Cider workflow plugin for Codex or Claude Code is a separate, reviewed install step.

Usage connections live under **Usage → Connection settings**. Cider can use the existing agent sign-in or a supported command-line source, depending on the provider. See [Features](#/docs/features) for provider details and the other parts of Cider.

## A few useful shortcuts

When Notes is active:

- **⌘N** creates a note.
- **⇧⌘O** adds a workspace folder.
- **⌘W** closes the active note tab.
- **⌘S** saves the active note.
- **⇧⌘[** and **⇧⌘]** switch note tabs.

Use the menu-bar item to open the workspace or toggle the notch when the main window is closed.
