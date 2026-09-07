# AI Development Instructions

This repository is developed with AI-assisted planning and implementation.

## Source of truth

Before changing code, read these in order:

1. The active GitHub Issue and its acceptance criteria.
2. `docs/AI_PROGRESS.md` for repository-wide integration state.
3. The progress file for the active implementation lane:
   - `docs/AI_PROGRESS_OBJECT.md` — Object Core & Body.
   - `docs/AI_PROGRESS_RELATION.md` — Relations & Data Integrity.
   - `docs/AI_PROGRESS_DATABASE_VIEW.md` — Database, View & Schema UX.
   - `docs/AI_PROGRESS_PRIMITIVES.md` — Weblink/Image/File/Tag primitives and native media behavior.
   - `docs/AI_PROGRESS_SEARCH.md` — Search & Indexing.
   - `docs/AI_PROGRESS_STORAGE.md` — Storage, Vault & Delivery.
   - `docs/AI_PROGRESS_REFACTOR.md` — Refactor & Architecture Health.
4. Existing code, tests, and repository documentation.

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only. New implementation runs should not use it as their primary writable handoff file.

GitHub is the durable handoff layer between chat sessions. Do not rely on chat history alone.

## Seven-lane development model

The project may be implemented concurrently in seven focused lanes. The split is by responsibility, not by file count. Each PR must have exactly one primary lane even when an Issue spans multiple lanes.

### Lane A — Object Core & Body

Primary scope:
- Object/ObjectType identity and core semantics
- Property value/type semantics that are not presentation-specific
- Body/block/reference model and universal Body capability
- aliases and shared Object identity/search metadata contracts
- Daily Note identity/navigation/time-based Object patterns
- generic Object opening/detail contracts
- user-defined ObjectType core behavior
- Value-to-Object promotion contracts when they are not primitive-specific

Progress file: `docs/AI_PROGRESS_OBJECT.md`

Does not own Weblink/Image/File product implementation, Database/View layout UX, search indexing, Vault/filesystem lifecycle, or generic refactoring.

### Lane B — Relations & Data Integrity

Primary scope:
- canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle
- bidirectional Relation integrity
- Relation write validation and target/source/cardinality constraints
- delete/detach/retarget/retry/idempotency correctness
- stale/inconsistent Relation metadata handling
- Relation-producing workflow regressions
- Tag hierarchy integrity where expressed through Relations
- data-integrity side of schema evolution, especially Relation target/cardinality changes
- cross-object deletion/reference integrity and fail-closed corruption behavior

Progress file: `docs/AI_PROGRESS_RELATION.md`

This lane may remain production-code-light when the Relation subsystem is stable, but it should take independent integrity/test work when schema evolution or new Relation-producing workflows create correctness obligations. Do not invent speculative Relation abstractions merely to keep the lane busy.

### Lane C — Database, View & Schema UX

Primary scope:
- Database collection semantics
- View persistence and behavior
- Table/List/Gallery/Board presentation contracts
- Filter/Sort/Group/Layout/visible Properties
- Property-authoring UX, including Relation Property authoring surfaces
- user-owned template/domain schema instantiation
- generic Gallery cover/media-source configuration
- safe schema-editing UX and migration prompts, coordinated with Lane B for integrity-sensitive changes

Progress file: `docs/AI_PROGRESS_DATABASE_VIEW.md`

This lane owns generic presentation/configuration contracts, not Weblink/Image/File-specific product semantics.

### Lane D — Primitive Objects & Media

Primary scope:
- Weblink identity, URL normalization, metadata/enrichment and media orchestration
- Image identity/provenance/import/editing and Photo -> Image migration
- canonical generic File primitive
- Tag built-in/default semantics where work is not purely Relation-integrity
- managed-file/native capability infrastructure shared by Image/File
- MIME/content import classification and routing
- PDF/File preview, thumbnail, metadata and extracted-text production behavior

Progress file: `docs/AI_PROGRESS_PRIMITIVES.md`

This lane owns primitive Object product semantics and services. It does not own generic Gallery/View settings or Vault switching lifecycle.

### Lane E — Search & Indexing

Primary scope:
- canonical Object search architecture
- FTS correctness, incremental refresh and stale-token behavior
- indexing title/aliases/Properties/Body/Weblink metadata
- derived File/PDF extracted-text indexing
- ranking/filter context and search-result opening behavior
- search rebuild/reconciliation behavior

Progress file: `docs/AI_PROGRESS_SEARCH.md`

New domains should contribute to the canonical Object search projection rather than adding separate long-term search repositories.

### Lane F — Storage, Vault & Delivery

Primary scope:
- Vault/Profile directory lifecycle and user-selectable storage
- filesystem-level managed storage boundaries shared by primitives
- profile-relative/Vault-relative path handling
- backup/restore/profile duplication
- missing/offline path recovery
- app release/install packaging and delivery plumbing

Progress file: `docs/AI_PROGRESS_STORAGE.md`

Coordinate with Lane D: Lane F owns filesystem/Vault lifecycle; Lane D owns Image/File/Weblink Object identity and product semantics.

### Lane G — Refactor & Architecture Health

Primary scope:
- Issue #225 maintainability work
- behavior-preserving extraction and responsibility reduction
- legacy Bookmark/Photo dependency inventory and caller-zero retirement after replacement parity
- `AppDatabase` narrowing and migration-body extraction with regression coverage
- error/fallback observability improvements
- maintainability guardrails and architecture-boundary enforcement
- temporary shim retirement and incremental movement toward `lib/features/...` ownership

Progress file: `docs/AI_PROGRESS_REFACTOR.md`

The Refactor lane must not redesign working Relation semantics or hide product changes inside refactor PRs. Prefer deletion and small extraction over adding abstraction for its own sake.

## Ownership and concurrency rules

Each implementation run must identify exactly one primary lane before editing code.

- Do not modify another lane's progress file unless recording a cross-lane dependency or repository-wide coordination change.
- An Issue may span multiple lanes; split implementation by coherent acceptance slices and sequence dependencies rather than creating a broad cross-lane PR.
- Before non-trivial edits to shared hotspots such as `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, or `app_database.dart`, inspect current open PR ownership.
- Shared hotspots use a temporary ownership lease: only one lane at a time may own a broad edit to the same hotspot. Other lanes should choose service/domain/test slices or wait for the lease to clear.
- A patch-sized non-overlapping hunk may proceed only after confirming the active PR does not overlap the same behavior/region.
- If a change necessarily spans lanes, document the dependency in both the Issue and active lane handoff, then prefer sequencing.
- Shared architectural decisions belong in the active GitHub Issue and may also be summarized in `docs/AI_PROGRESS.md`.
- Relation subsystem redesign is not a Refactor-lane goal; preserve canonical Relation APIs unless a concrete Relation issue explicitly requires otherwise.
- Do not create another lane solely because a file is busy. Split by responsibility, not by temporary file ownership.
- Idle is acceptable when a lane has no independent safe work; never create speculative abstractions merely to keep a lane active.

## Initial issue routing

This routing is a starting point, not a substitute for reading each active Issue.

- **Object Core & Body:** #481 and core #56 slices.
- **Relations & Data Integrity:** integrity side of #493; Relation regressions from #491/#492/new primitive workflows.
- **Database, View & Schema UX:** #490, #491 UX, #492, and generic presentation portions of #249/#56.
- **Primitive Objects & Media:** #155, #245, #484, #489, #495.
- **Search & Indexing:** #414, #494.
- **Storage, Vault & Delivery:** #242, #218 and filesystem/backup slices.
- **Refactor & Architecture Health:** #225.

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
13. Update `docs/AI_PROGRESS.md` when repository-wide integration state, dependencies, routing, or priorities changed.

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
- hotspot lease/ownership if relevant
- known blockers or risks
- explicit reason the run stopped, matching one of the stopping criteria above

The next AI run should be able to resume from GitHub state without needing the user to restate context.

## Safety and scope

- Do not expose secrets or credentials.
- Do not delete user data or perform destructive migrations without explicit approval.
- Do not silently broaden scope beyond the active Issue.
- Prefer reversible changes and focused PRs/checkpoints.
- Existing historical migrations are compatibility contracts: extract/refactor them only with regression coverage and preserve semantics/order.
- If a product/design decision is genuinely ambiguous and materially changes behavior, record the alternatives and blocker in the relevant progress file instead of inventing a major requirement.

## Branch and integration policy

- Use dedicated branches for non-trivial implementation work.
- Prefer lane-identifiable branch names:
  - `feature/object-*`
  - `feature/relation-*`
  - `feature/database-view-*`
  - `feature/primitives-*`
  - `feature/search-*`
  - `feature/storage-*`
  - `refactor/issue-*`
- A sustained run may create multiple focused commits and, when appropriate, multiple sequential PRs; opening a PR does not automatically end the run.
- Keep `main` releasable.
- Rebase or refresh from latest `main` before integration when another lane has merged overlapping foundation changes.
- Merge after relevant checks pass or when the user explicitly directs integration.
- When multiple agents are working, avoid editing unrelated areas merely to reformat them.
- Do not let two lanes concurrently own a broad refactor of the same core file; split or sequence the work first.

## Commit hygiene and CI reruns

This policy applies to every implementation lane A–G.

- Every commit must represent a coherent repository change with a real code, test, documentation, migration, or configuration purpose.
- Do **not** create commits solely to trigger CI, create activity, advance `main`, or force another workflow run.
- Do **not** add temporary marker files such as `noop`, `tmp`, `oops`, `x`, `ignore`, or equivalent files and then remove them in a follow-up commit.
- Do **not** use meaningless whitespace, formatting churn, comment churn, or unrelated documentation edits as a CI trigger.
- If CI should be rerun, use the existing GitHub workflow/check rerun mechanism when available. If rerun tooling is unavailable, wait for the next meaningful repository change rather than manufacturing one.
- Never merge an artificial CI-trigger/no-op commit into `main`.
- A cancelled superseded CI run is acceptable; the latest meaningful commit is the one that needs to become green.

See `docs/noop_commit_policy.md` and Issue #225 for the maintenance rationale and examples.

## Planning chat vs implementation chats

Planning work should produce or refine a GitHub Issue with a clear goal, scope, acceptance criteria, lane ownership, and implementation notes.

Implementation chats should each adopt one lane, treat the Issue as the contract, continue through multiple safe slices per run, and keep the matching lane progress file current.

A practical chat split is:

- Planning / design chat
- Implementation chat A: Object Core & Body
- Implementation chat B: Relations & Data Integrity
- Implementation chat C: Database, View & Schema UX
- Implementation chat D: Primitive Objects & Media
- Implementation chat E: Search & Indexing
- Implementation chat F: Storage, Vault & Delivery
- Implementation chat G: Refactor & Architecture Health

Creating separate chats is recommended for concurrent work, but it is not required for the repository workflow to function.
