---
name: working-with-cider
description: Plan, implement, or review Cider, the native macOS agent-work companion. Route to the relevant product, Swift isolation, notch, editor, integration, and verification contracts without loading the entire project.
---

# Working with Cider

Read [current progress](../../../docs/progress/current.md), then choose one route below. The current user request determines scope; a future work order is not permission to start it.

| Task | Load next |
| --- | --- |
| Product or phase planning | [Planning route](references/planning.md) |
| Native UI, windows, rendering, Swift state | [Native route](references/native.md) |
| Providers, persistence, files, agent events | [Data route](references/data.md) |

## Decisions that must survive handoffs

1. Separate execution, attention, and verification. Never convert an agent's `Stop` or completed turn directly into a verified feature.
2. Keep built-in-display selection separate from focused-display selection.
3. Use black/ember tokens, small native components, explicit actor isolation, and bounded work. Verify performance instead of guessing from the language choice.
4. Preserve ordinary Markdown and relative image assets. Frontmatter and unsupported blocks must survive edits.
5. Capability-check connectors. Source excerpts or host-only tools are not proof that a standalone app can control existing sessions.
6. Report which claims come from source inspection, simulated behavior, native testing, or live integration.

## Finish a bounded work order

Update current progress with the result and next gate; link detailed evidence rather than pasting it here. Record deviations in the work order. Provide changed files, checks actually run, and outstanding blockers. Keep shared contracts owned by the coordinator during concurrent work.

