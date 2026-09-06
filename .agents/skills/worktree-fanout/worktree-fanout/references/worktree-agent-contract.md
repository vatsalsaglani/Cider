# Worktree (lane) agent contract

Scope: what an agent implementing one plan inside a worktree must do, may
decide, and must report. Independently readable. Written to both audiences:
the coordinator pastes rules from here into start prompts, and a lane agent
can be pointed at this file directly.

## The deal

The plan tells you the goal, the files, the edits, and the checks. In
exchange, you stay inside it: you are one lane of a parallel round, and the
guarantees that make the round mergeable are yours to keep.

## Must

- Work on the branch the plan names (`<workstream>/NN-<slug>`). Never a
  branch starting with `codex/` or `claude/`.
- Read `00-overview.md` and your own plan file first. Read the files in
  your plan's "Context you need" list. That list is your reading list —
  needing to search the repo widely usually means you are drifting off-plan
  (or the plan has a gap: that is a Deviation, see below).
- Create or edit only the files in your plan's ownership list.
- Never edit: another plan's files, frozen contract files, `00-overview.md`
  (statuses belong to the coordinator), or shared repo docs/configs your
  plan does not own.
- Run every command in your plan's Verification section and make them pass.
- Commit on your branch with plain, descriptive messages. Do not merge,
  rebase onto other lanes, or push anywhere the plan does not say to.

## May — you are the implementer, and the plan met reality second

You are expected to make independent calls when implementation shows
something the planner did not see: a better internal structure, a missed
edge case, a helper the plan forgot, an anchor that moved, a described
approach that does not compile or race-tests poorly. Decide, implement,
keep going — **inside your ownership list**. You do not need permission for
decisions confined to your own files.

What you may never decide alone: changing a frozen contract surface,
touching a file you do not own, expanding your scope into another plan's
goal, or skipping a verification step. If the right fix truly lives in a
file you cannot touch, implement the best version possible inside your
boundary and hand the rest to the coordinator through a Deviation.

## Deviations — the confession ledger

Every departure from the written plan is appended to **your own plan
file** under `## Deviations`, one bullet each, at the moment you make the
call (not reconstructed at the end):

```markdown
## Deviations
- <what you did differently> — Why: <the reason, one or two plain
  sentences>. Affects: <files/plans/contract surfaces touched by the
  consequence, or "none beyond this lane">.
- CONTRACT CHANGE NEEDED (not made): <frozen surface> should <change>.
  Why: <reason>. I coded around it by <workaround>.
```

Record even "harmless" departures — a renamed helper, a skipped optional
step, an extra test. The coordinator reads this section before your diff;
an empty Deviations section paired with a surprising diff destroys trust in
the whole round. "No deviations" is itself worth stating.

## Final report

End with, in this order:

1. What is true now (the plan's Goal, confirmed or qualified).
2. Verification output summary — every command from the plan, pass/fail,
   with failures quoted, never paraphrased away.
3. Deviations — restate the bullets (or "none").
4. Anything the coordinator should check at merge time (integration risks,
   files you noticed drifting, follow-ups that belong in a new plan).
