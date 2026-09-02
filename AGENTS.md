# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active GitHub Issue and its acceptance criteria.
2. `docs/AI_PROGRESS.md` for repository-wide integration state.
3. The progress file for the active implementation lane:
   - `docs/AI_PROGRESS_DB_VIEW.md` for Database / View / query / layout / database-page UX work.
   - `docs/AI_PROGRESS_OBJECT_RELATION.md` for Object / ObjectType / Property / Relation / Tag / Daily Note / Body work.
4. Existing code, tests, and repository documentation.

GitHub is the durable handoff layer between chat sessions. Do not rely on chat history alone.

## Two-lane development model

The project may be implemented concurrently in two focused lanes.

### Lane A — Database / View

Primary scope:
- Database collection semantics
- Database-level collection filters
- View configuration and persistence
- multiple Views and top-tab navigation
- Filter / Sort / Group / layout integration
- Gallery / List / Table / Board projection consistency
- GenericDatabasePage and database-level UX
- Object opening presentation when the work is primarily database-navigation related

Progress file: `docs/AI_PROGRESS_DB_VIEW.md`

### Lane B — Object / Relation

Primary scope:
- Object and ObjectType model
- Property type system
- Value vs Object Relation properties
- Relation / backlink lifecycle
- Tag as Object and hierarchical tags
- Weblink / Image / other reusable Object types
- Object detail content architecture
- Body / block model
- Daily Note and time-based Object patterns
- Value-to-Object promotion

Progress file: `docs/AI_PROGRESS_OBJECT_RELATION.md`

### Ownership rule

Each implementation run must identify exactly one primary lane before editing code.

- Do not modify the other lane's progress file unless recording a cross-lane dependency.
- Avoid large edits to files currently owned by another active lane.
- If a change necessarily spans both lanes, keep it small, document the dependency in both lane files, and prefer sequencing the work instead of concurrent edits to the same core file.
- Shared architectural decisions belong in the active GitHub Issue and may also be summarized in `docs/AI_PROGRESS.md`.

## Autonomous implementation loop

When an implementation task is active, continue without asking for confirmation for routine engineering decisions that are reversible and scoped to the active Issue.

1. Inspect the latest `main`, active branch, Issue, PR, and relevant CI state.
2. Read the repository-wide handoff and the active lane handoff.
3. Identify the next unfinished acceptance criterion for that lane.
4. Implement the smallest coherent slice.
5. Add or update tests when practical.
6. Run the most relevant validation available in the environment.
7. Fix failures that are caused by the change.
8. Commit and push coherent progress.
9. Update the active lane progress file before ending the run.
10. Update `docs/AI_PROGRESS.md` when repository-wide integration state, dependencies, or priorities changed.
11. If the work is complete, open or update a PR and clearly record completion.

## Handoff requirement

Before a run ends, always update the active lane progress file with:

- current goal and active Issue
- branch and latest relevant commit
- completed work
- work in progress
- exact next actions in priority order
- tests/validation performed and results
- cross-lane dependencies
- known blockers or risks

The next AI run should be able to resume from GitHub state without needing the user to restate context.

## Safety and scope

- Do not expose secrets or credentials.
- Do not delete user data or perform destructive migrations without explicit approval.
- Do not silently broaden scope beyond the active Issue.
- Prefer reversible changes and focused PRs.
- If a product/design decision is genuinely ambiguous and materially changes behavior, record the alternatives and blocker in the relevant progress file instead of inventing a major requirement.

## Branch and integration policy

- Use a dedicated branch for each non-trivial implementation slice.
- Prefer lane-identifiable branch names such as `feature/db-view-*` and `feature/object-*` where practical.
- Keep `main` releasable.
- Rebase or refresh from latest `main` before integration when another lane has merged overlapping foundation changes.
- Merge after relevant checks pass or when the user explicitly directs integration.
- When multiple agents are working, avoid editing unrelated areas merely to reformat them.
- Do not let both lanes concurrently own a broad refactor of the same core file; split or sequence the work first.

## Planning chat vs implementation chats

Planning work should produce or refine a GitHub Issue with a clear goal, scope, acceptance criteria, and implementation notes.

Implementation chats should each adopt one lane, treat the Issue as the contract, execute only that lane's current slice, and keep the matching lane progress file current.

A practical chat split is:

- Planning / design chat
- Implementation chat A: Database / View lane
- Implementation chat B: Object / Relation lane

Creating separate chats is recommended for concurrent work, but it is not required for the repository workflow to function. Any implementation chat can resume either lane by reading GitHub state and the corresponding progress file.
