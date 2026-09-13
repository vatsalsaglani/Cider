# Notes

Cider works with ordinary Markdown files in folders you choose. The Notes workspace gives those files a nested tree, tabs, an open writing surface, and links to related tasks and agent activity while keeping the files usable outside Cider.

![Cider Notes workspace](images/notes.png)

## Add folders and open notes

Choose **Add folder** in the Notes sidebar or press **⇧⌘O**. Cider shows Markdown files beneath each selected folder, with folders before files and a disclosure tree for nested paths. Expand a folder, then select a note to open it in a tab.

Use the tab strip to move between open notes. The selected note, open tabs, and expanded folders are restored when Cider starts again. Folder context menus include creating a note, revealing the folder in Finder, removing a workspace folder, and copying its path. Note context menus add opening or closing a tab, renaming a note, and viewing connections.

If no folder is selected, **New note** creates and remembers `~/Documents/Cider`. You can also create a note inside the selected folder from its context menu.

## Write in Markdown

The editor is a full writing surface. It renders headings, lists, links, tables, fenced code, and Mermaid diagrams, while keeping the Markdown file as the saved source. Click a supported local Markdown link to open another note; web, mail, and other supported external links open through macOS.

Paste or drop a supported image into a note and Cider saves a PNG beside the note in a matching `.assets` folder, then inserts a relative Markdown image link. Relative assets remain portable with the note folder.

## Save safely

Cider saves after a short pause while you type and supports explicit **⌘S**. **Close Tab** also gives the active note a chance to save. If the file changed elsewhere or a write fails, Cider keeps your writing open and shows an unsaved state so you can recover it. A draft from an interrupted session is shown as **Recovered draft** when it is available.

The **Properties** disclosure shows a note’s leading YAML frontmatter when present. Existing frontmatter and unsupported content remain part of the file; Cider does not silently replace the file with a simplified version.

## Link notes to work

Use a note’s link button or context menu to open **Connected work**. From there, attach the note to a task as a plan, context, or evidence reference, open the task, remove the link, or view the relationship in **Graph**. These saved links describe related work without inserting task metadata into your Markdown.

From a task’s Notes section, link an existing note or create a linked note in a chosen workspace folder. A response checkpoint can also be previewed and appended to a selected note after confirmation.

## Keyboard shortcuts

When Notes is active, Cider provides:

- **⌘N** — New Note
- **⇧⌘O** — Add Workspace Folder
- **⌘W** — Close Tab
- **⌘S** — Save Note
- **⇧⌘[** / **⇧⌘]** — Previous / Next Tab

Use the sidebar and note context menus when you prefer pointer or VoiceOver navigation.
