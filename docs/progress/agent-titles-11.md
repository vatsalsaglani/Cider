# Codex chat names in agent cards

Implemented 6 September 2026.

The shared workspace/HUD agent card now uses the Codex chat name as its heading, with the workspace underneath. Headings allow two lines and retain a full-name tooltip. Search matches either chat or workspace. Missing names fall back to the workspace and a short session suffix; identical names in the same workspace also show a suffix. Session identity and click destinations remain unchanged.

## Observation source

Names come from the local `CODEX_HOME/session_index.jsonl` (default `~/.codex/session_index.jsonl`), matched only against session IDs already received through tracking hooks. The current installed app's index supplied distinct names for the user's two `df-ai-session` sessions: “Improve web Sightline search flow” and “Improve web Sightline search flow (2).”

This is an internal local metadata adapter, not a public subscription to Codex's app process. Cider opens no rollouts or authentication stores and does not resume a chat. Reads run on AgentIO, inspect at most the final 4 MiB, skip partial/malformed/oversized rows and symlinks, retain only requested IDs, and bound each plain-text name to 200 characters. The last complete matching index row wins. A missing or incompatible index leaves activity usable. Existing names are retained in memory on read errors.

Refresh occurs on initial observation, when the observed session set changes, and through the existing 30-second activity clock, so an idle chat rename also updates. Names are a display projection and never drive execution or attention state. New Codex installations and custom-home configurations still depend on that index being available to Cider. Names older than the bounded tail use the fallback.

No hook changes, observer upgrade or Codex restart are needed.

## Verification

- `swift test`: 45 tests passed, including name matching, same-workspace sessions, latest rename, bounded/partial JSONL handling, plain-text bounds, symlink/missing-file behavior and stable workspace/identity fallback.
- `script/build_and_run.sh --verify`: native app/helper build, signing and relaunch passed.
- Live local metadata lookup resolved both requested chat names by exact session ID.
- Native accessibility inspection of the running Agents workspace showed both headings across its scroll positions; screenshot inspection confirmed the name above `df-ai-session` and the source action intact.
- The notch uses this same shared card in compact mode. This pass did not capture a separate physical-notch screenshot or rename a user's live chat for testing; renames were tested with synthetic index replacement.

Changed surfaces: bounded CiderData title adapter, optional domain display title, tracking-model title refresh, shared Agents card/search/disclosure, tests and progress docs.
