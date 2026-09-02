# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active GitHub Issue and its acceptance criteria.
2. `docs/AI_PROGRESS.md` for repository-wide integration state.
3. The progress file for the active implementation lane:
   - `docs/AI_PROGRESS_OBJECT.md` for Object/ObjectType/Property/Database-View integration/Body/Daily Note work.
   - `docs/AI_PROGRESS_RELATION.md` for Relation/backlink/bidirectional lifecycle/relation integrity work.
4. Existing code, tests, and repository documentation.

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only. New implementation runs should not use it as their primary writable handoff file.

GitHub is the durable handoff layer between chat sessions. Do not rely on chat history alone.

## Two-lane development model

The project may be implemented concurrently in two focused lanes.

### Lane A — Object

Primary scope:
- Object and ObjectType model
- Property value/type semantics
- Object-centric Database/View integration
- reusable Object types
- Object detail content and opening presentation
- Body/block model
- Daily Note and time-based Object patterns
- Value-to-Object promotion contracts

Progress file: `docs/AI_PROGRESS_OBJECT.md`

### Lane B — Relation

Primary scope:
- Relation and backlink lifecycle
- bidirectional Relation integrity
- relation write validation and target/source constraints
- rename/delete propagation
- stale/inconsistent relation metadata handling
- Relation APIs used by Object detail and Daily Note features
- Tag hierarchy where expressed through Relations

Progress file: `docs/AI_PROGRESS_RELATION.md`

### Ownership rule

Each implementation run must identify exactly one primary lane before editing code.

- Do not modify the other lane's progress file unless recording a cross-lane dependency.
- Avoid large edits to files currently owned by another active lane.
- If a change necessarily spans both lanes, keep it small, document the dependency, and prefer sequencing instead of concurrent broad edits to the same core file.
- Shared architectural decisions belong in the active GitHub Issue and may also be summarized in `docs/AI_PROGRESS.md`.

## Autonomous implementation loop

When an implementation task is active, continue without asking for confirmation for routine engineering decisions that are reversible and scoped to the active Issue.

1. Inspect the latest `main`, active branch, Issue, PRs, and relevant CI state.
2. Read the repository-wide handoff and the active lane handoff.
3. Identify the next unfinished acceptance criterion for that lane.
4. Implement one coherent slice.
5. Add or update tests when practical.
6. Run the most relevant validation available in the environment.
7. Fix failures caused by the change.
8. Commit and push the coherent slice.
9. Record the checkpoint in the active lane progress file.
10. **Do not end the run merely because one slice, one commit, or one PR is complete.** Immediately select the next safe, non-conflicting slice and continue.
11. If CI is pending, do not wait idly and do not treat pending CI alone as a reason to end the run. Continue with another task that does not depend on that CI result.
12. Repeat steps 3–11 for as many safe slices as the execution allows.
13. Update `docs/AI_PROGRESS.md` when repository-wide integration state, dependencies, or priorities changed.

### Expected run length / stopping criteria

The goal is useful sustained progress, not one tiny PR per chat turn. A normal implementation run should attempt multiple coherent checkpoints when work remains.

Stop only when at least one of these is true:

- the active lane has no remaining actionable work in the Issue;
- a genuine blocker requires user/product input not already resolved in the Issue;
- the next step would require a destructive migration, deletion of user data, secrets, or another materially risky irreversible action;
- the next safe step is blocked by an unavoidable cross-lane conflict or dependency;
- a failing validation must be resolved by external infrastructure and no independent safe work remains;
- the runtime/tool/session limit is actually reached.

The following are **not** sufficient reasons to stop by themselves:

- one PR was opened;
- one commit was pushed;
- one test suite passed;
- CI is merely pending or queued;
- the current slice is complete while other lane work is clearly available;
- a task can be continued safely on the same branch or a new focused branch.

Prefer several small commits and reviewable checkpoints during one sustained run rather than one oversized commit or ending after the first checkpoint.

## Handoff requirement

Before a run ends, always update the active lane progress file with:

- current goal and active Issue
- branch and latest relevant commit
- all checkpoints completed during this run
- work in progress
- exact next actions in priority order
- tests/validation performed and results
- cross-lane dependencies
- known blockers or risks
- explicit reason the run stopped, matching one of the stopping criteria above

The next AI run should be able to resume from GitHub state without needing the user to restate context.

## Safety and scope

- Do not expose secrets or credentials.
- Do not delete user data or perform destructive migrations without explicit approval.
- Do not silently broaden scope beyond the active Issue.
- Prefer reversible changes and focused PRs/checkpoints.
- If a product/design decision is genuinely ambiguous and materially changes behavior, record the alternatives and blocker in the relevant progress file instead of inventing a major requirement.

## Branch and integration policy

- Use dedicated branches for non-trivial implementation work.
- Prefer lane-identifiable branch names such as `feature/object-*` and `feature/relation-*` where practical.
- A sustained run may create multiple focused commits and, when appropriate, multiple sequential PRs; opening a PR does not automatically end the run.
- Keep `main` releasable.
- Rebase or refresh from latest `main` before integration when another lane has merged overlapping foundation changes.
- Merge after relevant checks pass or when the user explicitly directs integration.
- When multiple agents are working, avoid editing unrelated areas merely to reformat them.
- Do not let both lanes concurrently own a broad refactor of the same core file; split or sequence the work first.

## Planning chat vs implementation chats

Planning work should produce or refine a GitHub Issue with a clear goal, scope, acceptance criteria, and implementation notes.

Implementation chats should each adopt one lane, treat the Issue as the contract, continue through multiple safe slices per run, and keep the matching lane progress file current.

A practical chat split is:

- Planning / design chat
- Implementation chat A: Object lane
- Implementation chat B: Relation lane

Creating separate chats is recommended for concurrent work, but it is not required for the repository workflow to function.
