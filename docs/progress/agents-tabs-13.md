# Activity and agent connections

Implemented 6 September 2026.

The Agents workspace has two tabs using `CiderPillPicker`:

- **Activity:** tracked sessions, chat/workspace and provider filters, recent ended sessions, questions, response excerpts and existing source actions.
- **Agents:** Codex/Claude connection cards, installed versions, connection status and the existing reviewable Connect/Disconnect flow.

A new visit defaults to Activity if any supported provider is configured in Cider or a non-ended session has fresh activity. Otherwise it defaults to Agents so connection setup is visible. Old ended or stale sessions alone do not imply a connection. Once the user chooses a tab, incoming activity or connection changes do not override that choice. Activity filters survive switching between these tabs; returning from another workspace section applies the default again.

The compact notch keeps its activity-only content, without additional nested tabs. Observer installation, removal and proposal review are unchanged. No provider configuration or hook was modified during verification.

## Verification

- `script/build_and_run.sh --verify`: native app/helper built, signed and relaunched successfully.
- Live native screenshot and accessibility inspection: Activity selected with configured providers; session list and filters visible with setup cards removed from the activity area.
- Agents tab: Codex/Claude status/version cards and Disconnect actions visible, with session filters/list absent.
- Entered a workspace filter, switched to Agents and back: filter and corresponding activity remained selected. Cleared the temporary filter afterward.
- Switched to Agents, left for Usage, then returned: Activity was selected by default.
- The unconfigured default was verified by source inspection; existing user connections were not disconnected to exercise first-run setup. No new tests were added for this view reorganization.

Changed paths: `Features/Agents/AgentsView.swift`, `AgentConnectionsView.swift`, `AgentTrackingModel.swift`, and progress docs.
