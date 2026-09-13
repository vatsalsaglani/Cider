# Usage

Cider puts account quota windows beside your work so you can see limits before they interrupt a session. Enable the providers you use in **Usage → Connection settings**; Cider refreshes them in the workspace and the notch.

![Usage gauges in the notch](images/notch-usage.png)

## What Cider can show

| Provider | Source and reported windows |
| --- | --- |
| Codex | Your existing agent sign-in or its command line fallback. Session, weekly, and model windows appear when reported. |
| Claude Code | Your existing agent sign-in or its command line fallback. Session, weekly, and model windows appear when reported; Fable is shown when the account supplies it. |
| Cursor & Grok Bot | CodexBar reads the Cursor app sign-in or a cursor.com browser session. Cursor plan, model, third-party model, and account-reported Grok Bot allowances can appear. |
| Grok Build | Your Grok Build sign-in. The windows available depend on the account. |

Grok Bot and Grok Build are usage sources here. Cider does not currently track their live activity or show response peeks. Agent activity and quota availability are separate capabilities; see [Agents](#/docs/agents).

## Read a gauge

Switch between **Used** and **Remaining** with the pill control. The choice is shared between the workspace and notch and is remembered. Each row can include the account label, source, last update, window name, and reset countdown. The workspace adds per-window pace notes and more context; the notch keeps the same information compact.

An unknown gauge means the provider did not report a usable percentage, reset, duration, or fresh observation. Cider leaves it unknown instead of treating missing data as zero. A model window can also be absent on one refresh and appear later.

## Refresh and connection choices

Cider refreshes enabled providers about every ten minutes and after a tracked agent response. Use the refresh button for an immediate check. In **Connection settings**, choose **Automatic**, **Agent sign-in**, or **Agent command line** for Codex, Claude Code, and Grok Build. Automatic tries the available sign-in path and falls back to the command line. Cursor uses its own account session path.

Usage is supplied by the CodexBar helper bundled with Cider. If the helper is missing from an installation, Cider reports that state and asks you to reinstall rather than showing stale numbers as current.

## Pace notes

When a window has enough fresh data, Cider estimates what would happen if your average usage continued until reset. It labels the window **On pace**, **Tight**, **May run out**, or **Limit reached**. This is a planning estimate, not a promise: overlapping model limits remain independent, and Cider withholds the estimate when the data is too old, too early, invalid, or missing a reset time.

See [Notch](#/docs/notch) for the compact view and [Agents](#/docs/agents) for activity status.
