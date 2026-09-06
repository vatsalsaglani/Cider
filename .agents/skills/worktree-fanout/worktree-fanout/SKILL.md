---
name: worktree-fanout
description: >
  Use this skill when a task is too big for one agent in one shot AND splits
  into multiple independent parts — e.g. "divide this into parallel plans",
  "run these in separate worktrees", "fan this out", "plan set", a feature
  touching several deployables at once, a refactor with a shared
  contract/shim plus many consumers, or a bug-fix batch across independent
  files. It produces a committed plan set: a dependency graph (mermaid, with
  TODO / IN PROGRESS / DONE per plan), one plan file per parallel lane with
  file ownership, branch name, edits, and a copy-paste start prompt, plus a
  contract phase built first in the local checkout and a merge/validate loop
  after each round. Do NOT use it for tasks one agent can finish directly,
  or for work that is inherently sequential.
---

# Worktree fanout — plan, parallelize, merge, repeat

<!-- Distilled from: docs/plans/agent-e2e-impl/00-overview.md and its numbered
plans, docs/plans/ui-integration-loaders/00-overview.md and its numbered
plans, docs/plans/prompt-cache-layout.md and
docs/plans/web-agent-parity/manifest.md (worktree-standalone plan bar,
sequential sets), .agents/skills/AUTHORING.md conventions. Update those or
this together. -->

The pattern: one coordinator agent (you, in the local checkout) plans and
integrates; many lane agents (in git worktrees) implement. Work moves in
rounds until the whole dependency graph is DONE:

1. **Plan.** Explore the task, split it into lanes with disjoint file
   ownership, write the plan set, commit it.
2. **Contract first, locally.** Anything two or more lanes depend on —
   shared types, schemas, function signatures, stub files, naming — is built
   in the local checkout *before* fanning out, committed, and then frozen.
3. **Fan out.** Create every worktree for the round **from the same commit**
   (the one containing the contract and the plan set). One lane agent per
   plan, started with the plan's own start prompt.
4. **Merge, test, validate, update — locally.** The coordinator merges
   finished lanes, runs the verification listed in each plan, reviews each
   lane's Deviations section, fixes small integration issues itself, updates
   the graph statuses, and recommends the next round.
5. Repeat from step 3 with the plans the graph now unblocks.

## Universal rules

- **Disjoint ownership is the whole trick.** Two plans in the same round may
  never edit the same file. Shared files (root docs, configs, the overview)
  belong to the coordinator or to a dedicated solo integration plan.
- **Sequential plan sets are valid.** When the lanes must touch the same
  files (one subsystem, layered changes), keep the plan-set shape but run
  one lane at a time in numbered order: ownership disjointness then applies
  between *concurrent* lanes only, each worktree forks from the branch tip
  AFTER the previous lane merged, and the overview must say explicitly that
  the set is sequential and why. Worked example:
  `docs/plans/web-agent-parity/manifest.md`.
- **The contract phase is strict.** Freeze every shared surface a lane could
  disagree about: file paths, exported names, type/field names, status
  strings, error shapes, env var names. A lane that needs a contract change
  does not make it — it codes around it and records the need as a Deviation.
- **Worktrees fork from the post-contract commit, never earlier.** A lane
  built on a stale base writes stale content that merges cleanly and is
  wrong (this has happened; diff the lane base against the branch tip when
  in doubt).
- **Branch names**: `<workstream>/<NN>-<slug>` (e.g.
  `ui-loaders/03-chip-guards`). Never start a branch with `codex/` or
  `claude/`.
- **Plans are written in plain, simple English.** Short sentences, no
  jargon; a reader who has never seen the repo should follow every step.
  Name the exact files and, at least at a high level, the parts of each file
  to change — the lane agent should not need to search the repo to start.
- **Statuses live only in the overview graph** and are updated only by the
  coordinator in the local checkout. Lane agents never edit the overview.
- **Lane agents may decide, but must confess.** Implementation reality beats
  the plan; every departure goes into the plan file's `## Deviations`
  section with a justification (see the lane-agent reference).
- **After every merge round**, the coordinator posts the updated graph and a
  short "what to run next" recommendation.

## Routing

Read only the reference the current step needs.

| You want to... | Read |
|---|---|
| Write the overview + numbered plan files (templates, graph, start prompts) | `references/plan-set-anatomy.md` |
| Run the rounds: contract build, worktree creation, merging, validating, updating the graph | `references/lifecycle-and-merging.md` |
| Brief a lane agent, or act as one (ownership, deviations, final report) | `references/worktree-agent-contract.md` |
