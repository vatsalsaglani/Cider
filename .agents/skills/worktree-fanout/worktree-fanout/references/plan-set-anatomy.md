# Plan-set anatomy

Scope: the exact files a fanout plan set contains and the template for each.
Independently readable; the lifecycle (when to write what) is in
`lifecycle-and-merging.md`.

A plan set is a folder of markdown files, committed to the repo so every
worktree can read it. In this repo the home is
`docs/plans/<workstream>/`. Worked examples: `docs/plans/agent-e2e-impl/`
and `docs/plans/ui-integration-loaders/`.

```
docs/plans/<workstream>/
  00-overview.md          # rules, graph with statuses, ownership matrix
  01-<slug>.md            # one file per plan (contract plan is usually 01)
  02-<slug>.md
  ...
```

The overview may instead be named `manifest.md` when the requester asks for
that name (worked example: `docs/plans/web-agent-parity/manifest.md`); the
content contract is identical either way.

Copy-paste warning: inside the two templates below, the inner code fences
(mermaid, verification commands) are prefixed with an invisible zero-width
space so they can nest here. When copying a template, retype those fences as
plain triple backticks.

## `00-overview.md` template

```markdown
# <Workstream> — Implementation Plan Set (worktree/merge strategy)

Design source of truth: <link to the analysis/design doc, if one exists>.
One coordinator works in the local checkout; each numbered plan runs in its
own git worktree and merges back without conflicts.

## What is being built/fixed
<One plain-English paragraph per major piece. No jargon.>

## Conflict-free rules (binding for every agent)
1. Each plan has a file-ownership list. An agent may create or edit ONLY the
   files its plan owns.
2. Plans in the same round own disjoint files and merge in any order.
3. Frozen after the contract phase: <list every frozen file/surface>.
   Need a change to a frozen file? Do not make it — record it under your
   plan's `## Deviations` and code around it; the coordinator reconciles.
4. <Repo-specific rules: docstrings, test commands, secret hygiene, ...>

## Dependency graph and status

Statuses: TODO, IN PROGRESS, DONE. Only the coordinator edits this section.

​```mermaid
flowchart TD
    P01["01 contract + shims<br/>DONE"]:::done
    P02["02 lane A<br/>IN PROGRESS"]:::inprogress
    P03["03 lane B<br/>IN PROGRESS"]:::inprogress
    P04["04 lane C<br/>TODO"]:::todo
    P05["05 integration + docs<br/>TODO"]:::todo
    P01 --> P02
    P01 --> P03
    P01 --> P04
    P02 --> P05
    P03 --> P05
    P04 --> P05
    classDef done fill:#2e7d32,color:#fff,stroke:#1b5e20
    classDef inprogress fill:#f9a825,color:#000,stroke:#f57f17
    classDef todo fill:#eceff1,color:#37474f,stroke:#90a4ae
​```

## Plans and worktrees
| Plan | Branch | Scope root | Depends on | Runs in parallel with |
|---|---|---|---|---|
| `01-<slug>.md` | `<ws>/01-<slug>` | ... | — | — (local checkout) |
| `02-<slug>.md` | `<ws>/02-<slug>` | ... | 01 | 03, 04 |

## Merge order
<Which merges can land in any order; which must wait; the exact git
commands if they are not obvious.>

## File-ownership matrix (complete)
- **01**: <every file, one line per file, "(new)" / "(targeted edits)">
- **02**: ...

## Merge log and next recommendations
<Appended by the coordinator after every round: what merged, what the
verification showed, which plans to start next and why.>

## Agent start prompts
Each plan file ends with an "Agent start prompt" section — copy it verbatim
into the worktree agent.
```

Notes on the graph: put the status **inside the node label** (second line)
AND color it with the classDef, so it reads in plain text and in rendered
mermaid. Keep node ids stable (`P01`…) so diffs stay small.

## `NN-<slug>.md` (per-plan) template

```markdown
# Plan NN — <plain-English title>

Branch: `<workstream>/NN-<slug>`. Depends on: <plans or "nothing">.
Runs in parallel with: <plans>.

## Goal
<What is true when this plan is done, in 3–8 plain sentences. Say why in
one sentence, with a link to the design doc for the long story.>

## File ownership
- `path/one` — <new | targeted edits: which functions/sections>
- `path/two` — ...
Do NOT touch: <the tempting-but-forbidden files, named explicitly>.

## Context you need (read these first, nothing else)
- `path:lines-or-symbol` — <why this span matters, one line each>
<This list is the lane agent's whole reading list. If writing this section
is hard, the plan is not specific enough yet.>

## Precise edits
### 1. <file> — <what>
<Quote the code to locate (anchors move; quoted code does not). Give exact
new names/signatures for anything another plan or test will reference.
High-level is fine for internals; exact is required for shared surfaces.>
### 2. ...

## Constraints
<Rules that bound the lane agent's freedom: what stays byte-identical,
what must never be logged/rendered, perf notes.>

## Verification
​```
<exact commands, run from which directory>
​```
<Plus, when useful: a short manual scenario list for the final report.>

## Deviations
<Left empty by the planner. The lane agent appends one bullet per
departure from the plan: what changed, why, what it affects. See
`worktree-agent-contract.md`.>

## Agent start prompt
> Read `docs/plans/<ws>/00-overview.md` (conflict rules) and
> `docs/plans/<ws>/NN-<slug>.md`, then implement plan NN exactly.
> Goal: <one-paragraph restatement: the goal, the 2–4 headline edits, the
> ownership boundary ("only touch the files in the plan's ownership
> list"), the verification commands, and what the final report must
> include (including any Deviations)>.
```

## Worktree-standalone quality bar

A lane agent starts with zero conversation context, so every plan must
survive on its own (bar proven by `docs/plans/prompt-cache-layout.md`):

- **Evidence section**: why the change exists, with run ids, measured
  numbers, and the observed failure — not just the intended behavior.
- **Quote the code being changed.** Verbatim snippets with `file:line`
  anchors, and name the commit the anchors were verified against. Quoted
  code survives drift; bare line numbers do not.
- **Record the nuances as facts**, one bullet each: side effects that must
  be preserved (context-var sets, hooks), provider quirks, seeding paths,
  idempotency guards — anything a fresh reader would plausibly get wrong.
- **Point at data the worktree will not have.** Untracked paths (`.logs/`,
  local DBs) do not exist in a fresh worktree — give the absolute main-
  checkout path or the SQL/query alternative for anything sourced from
  them.
- **External gates go in the graph** as their own nodes (e.g. "mobile
  cache impl merged — EXTERNAL GATE") so a lane never starts on an
  unmerged dependency.
- **Definition of done** checklist at the end of the overview or plan:
  commits named, suites green, docs/skill/env files updated in the same
  commits, PR target stated.
- Restate the repo's binding rules the lanes always trip on (docstrings,
  env-doc sync, skill CHANGELOG in the same commit, offline-only e2e, no
  AI attribution) in the overview once, and reference it from every start
  prompt.

## Start-prompt rules

- Goal-mode voice: state the outcome, not a step list.
- Always reference both the overview and the plan's own file by path.
- Always restate the ownership boundary and the verification commands —
  they are the two things lane agents most often drift on.
- Always end by asking for the final report to list Deviations (or state
  there were none).

## The contract plan (usually plan 01)

The contract plan is special: it runs in the **local checkout**, not a
worktree, and everything it creates is frozen for the round. Be exhaustive —
a vague contract is the top cause of merge pain. It must pin, for every
shared surface: file paths and names, exported symbols and signatures,
type/field names, enum/status strings, error shapes, event names, env var
names, and test fixture locations. Stubs with docstrings and typed
signatures beat prose descriptions. List every frozen file in the overview's
rule 3.
