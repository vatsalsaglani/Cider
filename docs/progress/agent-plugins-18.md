# Optional Codex and Claude Code plugins

The user requested plugins exposing Cider's CLI and an optional installation during agent connection.

## Delivered

- Separate bundled Codex and Claude Code catalogs/manifests, each providing the `cider` plugin with a `workflow` skill for task/note reads, writes, journal notes and links. No MCP server or duplicate observer hooks.
- An unchecked install option in the connection review, and an optional remove action during disconnection. Existing connections expose install/reinstall/removal and status refresh on their agent cards. The project-only skill remains an alternative.
- Account-wide provider-managed installation, reviewed destination/argv and removal explanation. Cider stages its CLI and plugin in Application Support, then calls provider plugin-management commands. Installed cached launchers refer to the staged CLI, avoiding dependencies on the application bundle's original location.
- Status comes from each provider's plugin list. Exit codes are checked; a failed optional plugin step leaves the observer connection intact and offers retry. No plugin changes run on launch or preview.
- Provider state is rechecked before applying a plan. Edited snapshots, symlink destinations and unrelated marketplaces with the same name are refused. Reinstall retains a prior snapshot backup; removal leaves the local marketplace for reinstalling.

## Verification

- 154 Swift tests in 28 suites passed. New fixtures cover install/reinstall/removal, launcher arguments and quoted paths, changed settings, edited files, symlinks, marketplace collisions, false success output/nonzero exits and retry after partial installation.
- Codex Plugin Creator manifest validation, skill validation and Claude Code plugin/catalog validation passed.
- The production installer passed real Codex and Claude Code CLI installation, enabled-state verification, reinstall and removal with temporary `CODEX_HOME`/`CLAUDE_CONFIG_DIR` directories. No user agent settings or task/note data were changed by verification.
- The final native build/relaunch, strict deep signature check, cached plugin skill/launcher checks and staged CLI read-only synthetic verification passed.
- Native integration caught a directory-URL equality issue during reinstallation; canonical paths now compare without directory trailing-slash identity differences. Staging enumerates relative names rather than slicing absolute paths, preserving files under macOS `/var` aliases.

See [plugin layout and setup](../../Integrations/agent-plugins/README.md). Tests exercise provider CLI management and cached skill/launcher files; model-session skill invocation and interactive UI acceptance remain separate checks. CUA was not used.

## Changed areas

`Integrations/agent-plugins`, `AgentPluginSetup`, `AgentPluginPayload`, `PluginProcess`, `AgentPluginModel` and plugin/connection review views. The existing observer flow composes the optional plugin step only after observation setup succeeds. Packaging includes both marketplace roots. `script/verify_agent_plugins.sh --isolated` reproduces provider installation checks.

## Plugin branding follow-up

The Codex manifest now supplies Cider's existing mascot PNG for `logo`, `logoDark`, and `composerIcon`, with the ember brand color. Workflow skill metadata supplies matching small/large icons. The previous missing fields caused Codex's generic cube fallback. The source plugin received a CLI cachebuster, the app bundle was repackaged, and the already-installed Codex plugin was refreshed through AgentPluginSetup. Its enabled state and cached icon bytes/skill metadata were verified. Manifest and package signature validation passed. Claude's manifest is unchanged because this is Codex presentation metadata. Reopen the plugin detail page to refresh its presentation; no live UI inspection was used.
