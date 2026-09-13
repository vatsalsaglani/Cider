# Agents

Cider keeps the work around your agents in one calm place. See what Codex, Claude Code, and Cursor are doing, spot a request for your attention, and jump back to the exact source app when you need to respond.

![Agents activity in Cider](images/agents.png)

## Activity at a glance

Open **Agents → Activity** to see tracked sessions with their provider, chat or workspace, current state, latest response excerpt, and recent activity. Filter by provider or search chats and workspaces. Turn on **Recent ended** when you need to find a session that has just closed.

The activity list describes what the source reported:

- **Working** means the agent has started a prompt, tool action, or subagent run.
- **Needs attention** means Cider saw an approval request, question, or response error.
- **Finished responding** means the response stopped and Cider can show a short reply cue.
- **Ended** means the session has closed or is no longer available.

A finished response is not a verified result. Cider keeps execution, attention, and your own verification separate so you can check the work in context.

![Agent activity in the notch](images/notch-agents.png)

## Connect an agent

Open **Agents → Agents**, choose Codex, Claude Code, or Cursor, and review the connection before enabling it. Start a new session after connecting so the source can send fresh activity. Cursor tracking covers local Cursor sessions on this Mac.

While connecting Codex or Claude Code, you can select **Also install the Cider plugin**. The option is account-wide and optional. Cider shows the exact provider command and local destination before you apply it. For an existing connection, use **Install Cider plugin…**, **Reinstall plugin…**, or **Remove plugin…** from its card. Start a new agent session after an install or removal.

Tracking and the plugin are separate. If plugin installation fails, the connection can continue tracking activity; review the status and retry the plugin action when ready.

## What each provider can do

| Provider | In Cider today |
| --- | --- |
| Codex | Track existing sessions, show local chat names when available, preserve questions and response excerpts, and return to the recorded Codex task. |
| Claude Code | Track existing sessions, show attention and response activity, and return to the recorded source app. |
| Cursor | Track local activity through its reviewed connection flow. Exact run, approval, and reply actions are not inferred. |
| Grok Bot and Grok Build | Usage can appear in [Usage](#/docs/usage) when the account reports it. Live activity and response peeks are not available yet. |

## Questions and replies

Known question requests stay attached to the session after the brief notch peek disappears. Click the question or the source action to return to the original app. A matching reply clears that question; an asynchronous delivery event does not count as an answer.

Cider stores bounded session metadata and short response or question excerpts to make this view useful. It discards other prompts, tool inputs, and your answers. Cider can open a source session when its recorded process identity still matches; if it does not, it explains the issue instead of opening a different session.

## Related guides

Use [Notch](#/docs/notch) for glanceable activity and [Usage](#/docs/usage) for account windows. [CLI](#/docs/cli) explains how an agent can work with tasks and notes when you request it.
