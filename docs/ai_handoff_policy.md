# Durable AI handoff policy

GitHub Issues, pull requests, commits, and CI are the live source of truth for concurrent AI development. `docs/AI_PROGRESS*.md` files are durable resumable checkpoints, not a second live dashboard.

## What belongs in a lane handoff

Prefer facts that remain useful after other lanes merge:

- lane goal and the active/focused Issue contract;
- integrated checkpoints with Issue/PR/commit identifiers;
- durable architecture/correctness contracts established by those checkpoints;
- actionable next work in priority order;
- explicit cross-lane prerequisites or released dependencies;
- shared-hotspot policy or an active lease when it materially affects the next action;
- validation evidence for the last meaningful implementation checkpoint;
- known blockers/risks and the reason the previous run stopped.

## What does not belong as durable truth

Avoid unqualified volatile snapshots such as:

- “there are no open PRs”;
- “PR X is currently the only owner”;
- “CI is running now”;
- exact current `main` or branch heads presented as if they remain current indefinitely;
- lane-idle claims that depend only on a momentary issue/PR search.

When a time-sensitive snapshot is useful for explaining a historical decision, label it explicitly as a checkpoint with its date/commit and still require the next run to re-read live GitHub state.

## Handoff update timing

When durable handoff facts are already known before an implementation PR merges, prefer including the lane's handoff update in that same coherent PR. This reduces extra docs-only PRs and keeps the implementation plus resumable checkpoint together.

A separate post-merge handoff PR is appropriate when the fact genuinely depends on merge/CI completion. Keep that PR limited to durable facts; do not recreate a live ownership dashboard in Markdown.

## Competing or stale handoff PRs

Only one open PR should normally propose the next durable version of a given `docs/AI_PROGRESS*.md` file.

If a newer open PR or `main` already changed the same handoff file:

1. re-read the latest handoff and live GitHub state;
2. decide which PR is the authoritative newer checkpoint;
3. close/supersede the stale competing handoff rather than merging both snapshots in sequence;
4. recreate from current `main` only when the older durable facts are still missing.

A handoff branch that is materially behind `main` also needs its durable statements re-audited even when the same Markdown file has not changed, because dependencies and product state may have advanced elsewhere.

## Automation

`tool/handoff_pr_guard.py` provides advisory PR diagnostics for:

- another open PR changing the same durable handoff file;
- the same handoff file changing on `main` after the branch diverged;
- a handoff branch falling behind `main` by a configurable material-staleness threshold.

These warnings are coordination signals, not permission to skip the normal live GitHub audit. The guard is intentionally read-only and fail-soft.
