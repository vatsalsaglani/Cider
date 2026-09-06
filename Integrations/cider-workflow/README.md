# Cider workflow skill

This portable, read-only skill lets Codex or Claude Code summarize a Cider TODO in the conversation already open. Cider setup first previews the exact project-local destination, managed bytes, and safely quoted packaged executable path. It never edits global settings, PATH, hooks, credentials, TODOs, or Markdown notes.

Supported project-local destinations are `.agents/skills/cider-workflow/SKILL.md` for Codex and `.claude/skills/cider-workflow/SKILL.md` for Claude Code. The former matches the current Codex project skill convention documented by OpenAI; the latter is the conventional Claude Code project skill location. Generated files begin with YAML frontmatter, then carry a digest-bound managed marker. The installer refuses unrelated, edited, oversized, unreadable, or symlink-escaped files; it updates/removes only an unchanged digest-verified managed file.

Run the configured packaged executable with `todo context <UUID> --json`, `todo activity <UUID> --since <sequence> --json`, or `todo summarize-context --today --json`. Context has bounded task, contributor, note, and checkpoint data; explicit note content is bounded and remains within linked selected roots. Checkpoints can be previews, so summaries must distinguish reported results from actual verification.

Evidence checked 2026-09-07: [OpenAI customization documentation](https://learn.chatgpt.com/docs/customization/overview) lists Codex agent configuration and build-skills surfaces; [Anthropic's Claude Code memory documentation](https://docs.anthropic.com/zh-CN/docs/claude-code/memory) documents project-local instruction discovery. Provider UI acceptance and real provider skill loading remain Plan 09/manual-review gates.
