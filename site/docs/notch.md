# Notch

Cider’s notch HUD keeps the next useful thing close: remaining TODOs, agent activity, music, and usage. It stays attached to the MacBook display while you work on another screen, so a glance never moves your focus by itself.

![Agent activity in the notch](images/notch-agents.png)

## Open and dismiss the HUD

Move the pointer over the HUD and wait briefly, or click it. Hover opening is enabled by default and takes about 250 ms. The HUD collapses after the pointer leaves for about 450 ms unless you pin it. A click or keyboard shortcut can open it without hover.

Use **Pin notch** when you want the expanded view to stay open. Unpin it, press Escape, or close it to return to the compact view. Opening a task capture field keeps the HUD open while you type; submit or cancel returns it to its normal behavior.

## Four quick views

The expanded HUD uses one pill switcher for **Agents**, **TODO**, **Now Playing**, and **Usage**. The selected tab is remembered.

- **Agents** shows compact tracked activity and attention count. A fresh question or response can appear as a short five-second peek without taking focus.
- **TODO** shows the selected day’s unfinished tasks and **Add a task…**. Open a task for its details or mark it complete from the row.
- **Now Playing** follows the system player, with artwork, transport controls, and an ember equalizer while music is playing.
- **Usage** shows enabled provider gauges, reset timing, and the selected Used or Remaining view.

![Music controls in the notch](images/notch-music.png)

## Placement and display

Open Cider settings to choose whether the HUD appears on the MacBook display, whether hover opens it, and where it sits on the **Top**, **Left**, **Right**, or **Bottom** edge. Top placement stays centered around the camera housing; the position slider applies along the selected edge.

The HUD’s display anchor is independent from the workspace window. Focusing an external display does not move or hide the MacBook HUD. If the anchored display is asleep or unavailable, Cider temporarily hides the HUD and restores it when the display returns.

## Quiet visual cues

The mascot reflects the highest current activity: idle, working, needs your attention, or reply ready. The needs-attention state wins over a completion cue. These cues describe reported agent activity; they never claim that the underlying work has been verified.

The HUD respects Reduce Motion and visibility changes such as sleep or an occluded window. Motion pauses when it cannot be seen, and the music indicator becomes still when motion is disabled.

See [Agents](#/docs/agents) for provider tracking and [Usage](#/docs/usage) for quota details.
