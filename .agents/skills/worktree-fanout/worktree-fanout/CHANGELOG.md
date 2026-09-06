# Changelog

All notable changes to the `worktree-fanout` skill.

## [0.2.0] - 2026-08-20

### Added

- Sequential plan sets (SKILL.md universal rules): lanes that must share
  files run one at a time in numbered order, each worktree forking after
  the previous merge; disjoint ownership applies between concurrent lanes
  only. Worked example: `docs/plans/web-agent-parity/manifest.md`.
- `plan-set-anatomy.md`: the overview file may be named `manifest.md`; new
  "Worktree-standalone quality bar" section (evidence with run ids, quoted
  code over bare line anchors with the verification commit named, nuance
  ledger, pointers for data absent from fresh worktrees, external gates as
  graph nodes, definition-of-done, binding-rules digest in the overview) —
  distilled from `docs/plans/prompt-cache-layout.md`.

## [0.1.0] - 2026-08-14

### Added

- Initial skill, generalizing the plan-set pattern proven by
  `docs/plans/agent-e2e-impl/` and `docs/plans/ui-integration-loaders/`:
  - `SKILL.md` — when to fan out, the round-based lifecycle
    (plan → contract in local checkout → parallel worktrees → merge/
    validate/update locally → repeat), universal rules (disjoint ownership,
    strict frozen contract, same-commit fan-out, branch naming without
    `codex/`/`claude/` prefixes, plain-English plans, coordinator-owned
    statuses, lane deviations).
  - `references/plan-set-anatomy.md` — templates for `00-overview.md`
    (mermaid dependency graph with TODO/IN PROGRESS/DONE inside node
    labels, ownership matrix, merge log) and per-plan files (goal, file
    ownership, reading list, precise edits, verification, deviations,
    goal-mode start prompt referencing the plan file).
  - `references/lifecycle-and-merging.md` — coordinator loop: contract
    round, fan-out rules, merge/cherry-pick mechanics, lane-freshness
    check, graph updates, and next-round recommendations.
  - `references/worktree-agent-contract.md` — lane-agent must/may rules,
    the independent-decision policy, the Deviations ledger format, and the
    final-report shape.

### Notes

- The same-commit fan-out rule and the lane-freshness check encode a real
  failure from the skills-restructure workstream (lanes forked from a stale
  base produced content that merged cleanly but was factually outdated).
