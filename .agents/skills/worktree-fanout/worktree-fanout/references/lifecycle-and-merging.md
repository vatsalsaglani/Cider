# Lifecycle and merging

Scope: the coordinator's loop — planning, the contract phase, creating
worktrees, merging lanes back, validating, updating the graph, and choosing
the next round. Independently readable; file templates are in
`plan-set-anatomy.md`.

## Round 0 — plan

1. Explore the task and write the split. A good lane: one clear goal,
   disjoint files, finishable by one agent in one sitting, verifiable on its
   own. If two candidate lanes want the same file, either merge them into
   one lane or move the shared file into the contract/integration plan.
2. Decide the dependency graph. Common shape:
   `contract → N parallel lanes → integration/docs`. Big workstreams may
   need several parallel rounds; the graph carries all of them.
3. Write `00-overview.md` + one plan file per lane (templates in
   `plan-set-anatomy.md`). Statuses all start TODO.
4. **Commit the plan set.** Worktrees can only read committed files.

## Round 1 — contract, in the local checkout

Run the contract plan yourself (or with a non-worktree helper) directly in
the local checkout. Build every shared surface as real code: stub modules,
typed signatures, schemas, fixtures, naming. Freeze list goes into the
overview. Commit. Mark the contract plan DONE in the graph, mark the
unblocked lanes IN PROGRESS, commit the overview update.

Skip this round only when the lanes genuinely share nothing — then say so
explicitly in the overview ("no contract phase; lanes share no surface").

## Fan out

Create every lane worktree **from the same commit** — the one that contains
the contract and the plan set. Never reuse a worktree created before the
contract landed: a lane on a stale base produces content that merges
cleanly and is silently wrong. If a lane must be re-run later, make a fresh
worktree from the current integration tip.

Per lane: check out the plan's branch name (`<ws>/NN-<slug>`, never
`codex/…` or `claude/…`), start the agent with the plan's start prompt,
copied verbatim. Lanes commit on their own branch; they do not merge
anything themselves.

## Merge, test, validate — in the local checkout

When a lane reports done:

1. **Read its Deviations section first**, then its diff. Deviations tell you
   where to look; an empty Deviations section with a surprising diff is a
   red flag.
2. Check the lane's base: `git merge-base <lane-branch> HEAD` should be the
   fan-out commit. If the integration branch moved since (earlier merges),
   prefer `git merge --no-ff <lane-branch>`; ownership being disjoint makes
   conflicts structural errors, not normal events — if one appears, someone
   broke the ownership matrix; resolve by re-reading both plans, and record
   the resolution in the overview's merge log.
3. If a plain merge would drag unrelated history (lane branched from the
   wrong base), fall back to cherry-picking the lane's commits.
4. Run that plan's Verification commands, plus the repo's standard checks
   for the touched deployables.
5. Fix small integration issues yourself in the local checkout (imports,
   doc links, one-line contract mismatches). Anything larger becomes a new
   plan file in the set — do not silently absorb big work.
6. Verify freshness: if reality changed under a lane while it ran (files it
   distilled from moved on), diff the fan-out commit against the current
   tip for the lane's source files and correct the content before or right
   after merging.

## Update the graph and recommend the next round

After each round of merges, in `00-overview.md`:

- Flip merged plans to DONE, newly unblocked plans stay TODO until started.
- Append to **Merge log and next recommendations**: what merged (branch →
  commit), verification results in one line each, deviations accepted or
  reverted, and which plans to start next with a one-line why (e.g. "03 and
  04 are now unblocked and independent — run both in parallel; 05 waits for
  both").
- Commit the overview update, then post the updated mermaid graph and the
  recommendation to the user.

The workstream is finished when every node is DONE and the final
integration plan's verification has passed on the merged local checkout.

## When lanes cannot all run in parallel

If the graph has depth (lane B needs lane A's output), do not fake
parallelism. Put A in an earlier round; create B's worktree only after A
has merged, from the post-merge commit. The overview's "Depends on" column
and the graph edges are the source of truth for what may start when — keep
them honest, and the recommendations write themselves.
