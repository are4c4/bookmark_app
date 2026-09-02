# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

The implementation is split into two concurrent-capable lanes matching the current implementation chats:

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - Object-centric Database/View integration
   - reusable Object types
   - Object detail content and Body/block model
   - Daily Notes and Value-to-Object promotion

2. **Relation lane** — `docs/AI_PROGRESS_RELATION.md`
   - Relation/backlink lifecycle
   - bidirectional Relation integrity
   - relation write validation and source/target constraints
   - rename/delete propagation and stale metadata handling
   - Relation APIs and Tag hierarchy expressed through Relations

`docs/AI_PROGRESS_OBJECT_RELATION.md` is retained only as legacy combined context. New runs should write to the dedicated Object or Relation handoff file.

Each implementation chat/run must pick one primary lane and update its matching progress file unless repository-wide integration state changes.

## Sustained-run policy

Implementation runs should not stop after the first small PR/commit/checkpoint when Issue #56 still contains safe work for that lane. After each coherent slice, commit/push, record the checkpoint, then continue with the next non-conflicting slice.

Pending/queued CI by itself is not a blocker. While CI is pending, continue with work that does not depend on the result. Stop only for a genuine design/risk/cross-lane blocker, external infrastructure with no independent work remaining, or an actual runtime/tool/session limit.

## Latest relevant state

- `main` includes the persistent AI handoff workflow and sustained multi-slice execution rules.
- Object-lane PR #61 (`Define Value vs Object Relation property semantics`) is merged to `main` as `b4b3845f0b687539c71db136649c9e0ba3727656`.
- Relation-lane PR #62 (`Harden bidirectional Relation pair integrity`) passed Flutter CI and is merged to `main` as `ed8d417f06a5190370dffbbe62bce84b3a64ec03`.
- Relation-lane PR #63 is active on `feature/relation-write-integrity`; it adds source/target Relation validation, canonical Relation writes, delete lifecycle protection, filtered backlink/outgoing queries, and regression coverage. Latest-head CI is running.
- Existing generic foundations include Object query/filter/sort, grouping, Board view, Board drag/drop persistence, Formula/Rollup, bidirectional Relations, ObjectType templates, and ObjectType management.
- Issue #56 remains the shared product/design implementation contract.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- Database = which Objects; View = how to see them.
- ObjectType = schema + defaults.
- Effective defaults resolve as `View override > Database override > ObjectType default > app default`.
- Object content = structured Properties + free Body designed for blocks.
- Property semantics distinguish Value, Object Relation, and computed properties.
- Tags are Objects; Select/MultiSelect remain for local option sets.
- Date is a Value; Daily Note is an Object keyed by a unique date.
- Object detail presentation should support side peek, center peek, and full page with shared content.

## Integration policy

- Keep `main` releasable.
- Use focused lane-specific branches/PRs/checkpoints.
- Avoid both lanes concurrently owning broad refactors of the same core file.
- If a change crosses lanes, document the dependency and sequence overlapping work where practical.
- Rebase/refresh from latest `main` before merging overlapping foundation changes.
- Preserve existing bookmark data and behavior; no destructive migrations without explicit approval.

## Next repository-wide actions

- Object lane resumes from `docs/AI_PROGRESS_OBJECT.md` and should continue through multiple safe slices per run.
- Relation lane should validate/integrate PR #63, then refresh from latest `main` before the next shared `object_store.dart` edit.
- Planning/design chat continues to refine Issue #56 when material product decisions are made.
- Integrate validated lane PRs into `main` in reviewable increments without treating each PR creation as the end of a chat run.

## Validation

- PR #62 Flutter CI passed before merge.
- PR #63 Flutter CI is running on its latest head; exact status is recorded in `docs/AI_PROGRESS_RELATION.md`.
- Feature runs must continue recording exact analyze/test results in their lane progress files.

## Known risks

- Parallel work is useful only when file ownership is reasonably separate; otherwise sequence the slices.
- `lib/data/object_store.dart` is shared foundation and should be refreshed from latest `main` before either lane makes another overlapping edit.
- GitHub Actions usage limits may affect CI availability; pending CI alone should not stop independent work.
- Block-editor and migration work can expand quickly; keep individual commits reviewable while allowing several checkpoints per run.
