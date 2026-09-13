# Document-first task workspace

Implemented the user-selected document-first study from design/task-navigation/options.html. A single editable title, compact status/date controls, expanding multiline description, criteria and linked-note rows replace the duplicate title, tabbed settings form and large blank editor. The reading column is limited to 720 points. Notes open by clicking their row; detach and occasional context actions live in menus. Chat attachment and activity expand inline. Save changes and an unsaved indicator appear when the draft differs from the saved task. Task disclosure/section scroll anchors are retained in the scene session.

Workspace history supplies a parent-task breadcrumb when visiting linked notes. Back/Forward continues to retain drafts; history remains scene-local. Native fields keep their existing validation and revision-conflict handling.

Changed TaskDetailView, TaskOverviewView, TaskLinksView, TaskDetailSession, WorkspaceHistory, WorkspaceView and WorkspaceHistoryTests.

Checks: all 158 Swift tests in 29 suites passed. Normal native build/relaunch passed. A separately signed QA bundle used a synthetic store: inspected the rendered task document; clicked its linked note, Back, Forward and the parent-task breadcrumb; changed a synthetic task title without saving, visited the note and returned, confirming the unsaved title and indicator remained. The first old fixture note failed because its folder was not registered in the fresh fixture defaults; a freshly registered sample note then completed the navigation checks. No live task or note data was changed during QA.

Remaining gates: long-content scroll restoration, compact-window layout and accessibility settings have not been verified interactively. The native screenshot is visual evidence, not user acceptance.
