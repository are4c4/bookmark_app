# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active GitHub Issue and its acceptance criteria.
2. `docs/AI_PROGRESS.md` for the latest handoff state.
3. Existing code, tests, and repository documentation.

GitHub is the durable handoff layer between chat sessions. Do not rely on chat history alone.

## Autonomous implementation loop

When an implementation task is active, continue without asking for confirmation for routine engineering decisions that are reversible and scoped to the active Issue.

1. Inspect the latest `main`, active branch, Issue, PR, and relevant CI state.
2. Identify the next unfinished acceptance criterion.
3. Implement the smallest coherent slice.
4. Add or update tests when practical.
5. Run the most relevant validation available in the environment.
6. Fix failures that are caused by the change.
7. Commit and push coherent progress.
8. Update `docs/AI_PROGRESS.md` before ending the run.
9. If the work is complete, open or update a PR and clearly record completion.

## Handoff requirement

Before a run ends, always update `docs/AI_PROGRESS.md` with:

- current goal and active Issue
- branch and latest relevant commit
- completed work
- work in progress
- exact next actions in priority order
- tests/validation performed and results
- known blockers or risks

The next AI run should be able to resume from this file plus GitHub state without needing the user to restate context.

## Safety and scope

- Do not expose secrets or credentials.
- Do not delete user data or perform destructive migrations without explicit approval.
- Do not silently broaden scope beyond the active Issue.
- Prefer reversible changes and focused PRs.
- If a product/design decision is genuinely ambiguous and materially changes behavior, record the alternatives and blocker in `docs/AI_PROGRESS.md` instead of inventing a major requirement.

## Branch and integration policy

- Prefer a dedicated branch for non-trivial changes.
- Keep `main` releasable.
- Merge after relevant checks pass or when the user explicitly directs integration.
- When multiple agents are working, avoid editing unrelated areas merely to reformat them.

## Planning chat vs implementation chat

Planning work should produce or refine a GitHub Issue with a clear goal, scope, acceptance criteria, and implementation notes.

Implementation work should treat that Issue as the contract, execute it, and keep `docs/AI_PROGRESS.md` current so another run can continue automatically.
