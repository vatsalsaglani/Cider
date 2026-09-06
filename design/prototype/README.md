# Canvas sources

This is an interaction prototype for the native Cider app, with synthetic data held only in its browser session.

- `shell.html`: workspace, sidebar, HUD, and feature composition.
- `base.css`: common content styling.
- `tasks.css`: task/calendar components and material illustration.
- `chrome.css`: shared rounded/tinted action controls, inset sidebar and compact rail.
- `document.css`: open writing surface, document typography and non-field focus treatment.
- `tasks.js`: shared task store and reusable TaskComposer, TaskRow, DateNavigator, WeekStrip, MonthCalendar, IconButton, and capture components.
- `app.js`: navigation, HUD lifecycle, notes, attention, and usage illustrations.

Run `python3 design/prototype/build_canvas.py` from the repository root to regenerate `design/cider-canvas.html`. The final fragment is self-contained for the conversation canvas; edit these sources instead of the generated file.

Icons and tooltips use the canvas host. For browser QA, wrap the generated fragment with the installed visualize skill's `scripts/render.py`; opening the raw fragment as an ordinary page omits those host facilities.

The task list/calendar/dates, task editing/completion, three task composers, editable note title/body, note draft switching, folder disclosure, image insertion, and annotation pins are interactive. This revision opens on an empty note so the writing surface is immediately reviewable. Notes are a visual editing illustration; Markdown source is read-only, and the diagram/code styles do not load Vditor, Mermaid, or a syntax parser. Provider actions are illustrative. Nothing is written to the filesystem or Jira from this canvas.
