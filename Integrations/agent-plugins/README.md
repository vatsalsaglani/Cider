# Cider agent plugins

Cider ships separate Codex and Claude Code plugin marketplaces. Both contain the `cider` plugin and a `workflow` skill that uses the existing Cider CLI for task/note reads and user-requested writes. They do not register an MCP server or duplicate tracking hooks.

## Installation in Cider

Open **Agents → Agents**. Connecting Codex or Claude Code offers an unchecked **Also install the Cider plugin** option. The review describes account-wide scope, local destination, exact provider commands and removal. Already-connected agents have **Install Cider plugin…**, **Reinstall plugin…** and **Remove plugin…** actions. Disconnect can optionally remove the plugin; otherwise it only removes tracking.

Installation stages the bundled plugin and CLI at `~/Library/Application Support/Cider/AgentPlugins/<provider>`. The copied launcher uses that stable CLI path, including paths with spaces or apostrophes. Cider registers its local `cider-bundled` marketplace and enables `cider@cider-bundled` through the provider's CLI. Start a new agent session after installation or removal. Refresh plugins rechecks the provider's status rather than trusting a saved checkbox.

Reinstall updates an unchanged managed snapshot and keeps a backup of the previous one. Edited files, symlink destinations, changed provider state and another marketplace using the same name are refused. The provider's own plugin manager can resolve conflicting registrations. Removal unloads the plugin through the provider and leaves Cider's local marketplace/helper files available for reinstalling. No user task/note data is removed.

Tracking and plugin installation are separate steps. If the optional plugin step fails, the observer remains connected; review status and retry the plugin action. Provider commands run with an argument array, checked exit status, bounded output and a timeout. No install runs at app startup or simply from opening the connection page.

## Layout and verification

- `codex/.agents/plugins/marketplace.json` and `codex/plugins/cider/.codex-plugin/plugin.json`.
- `claude/.claude-plugin/marketplace.json` and `claude/plugins/cider/.claude-plugin/plugin.json`.
- Each plugin's `skills/workflow/SKILL.md` references `scripts/cider`. The standalone source launcher expects a CLI staged by Cider; installed snapshots render the exact staged path.
- `script/build_and_run.sh` includes both catalogs in the application bundle.
- `script/verify_agent_plugins.sh --isolated` exercises the production installer with real provider CLIs, temporary configuration directories, install/reinstall/removal and the copied CLI launcher. Build/package Cider first. It does not start model runs or install into the user's agent configuration.

Bump the plugin manifest version when distributing changes to skills. Existing project-local `cider-workflow` skills remain unchanged; use either the plugin or the project-only alternative to avoid duplicate workflow instructions.

Claude Code's [plugin reference](https://code.claude.com/docs/en/plugins-reference) and [marketplace guide](https://code.claude.com/docs/en/plugin-marketplaces) document local catalogs and user-scope CLI installation. Codex manifests follow the Plugin Creator schema shipped with Codex; command syntax and JSON states were verified against the installed `codex plugin` CLI. General [OpenAI plugin documentation](https://learn.chatgpt.com/docs/plugins) does not establish these desktop CLI details.
