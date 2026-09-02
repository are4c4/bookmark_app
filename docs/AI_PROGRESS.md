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

- PR #61 is merged; Value / Object Relation / Computed property semantics are on `main`.
- PR #62 is merged; bidirectional Relation pair validation rejects broken inverse metadata.
- PR #64 is merged; Object promotion planning, versioned Body blocks, ObjectType defaults contract, and shared Object detail contracts are on `main`.
- PR #65 is merged; Object Body/defaults persistence, Weblink Object service, Daily Note open-or-create, detail loading, and safe plain-text Body adapter are on `main`.
- PR #66 is merged at `6770a5f1`; Relation source/target validation, stable mutation/read/index services, bidirectional lifecycle hardening, Relation-safe Object deletion, and Tag hierarchy cleanup are on `main`.
- Relation PR #69 is the active read-only integrity-audit slice and does not mutate user data.
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

- Object lane should consume the stable Relation services from merged PR #66 for relation-aware UI, promotion execution, Daily Note composition, and core-object synchronization rather than duplicating lifecycle rules.
- Relation lane should validate/integrate PR #69 and keep diagnostics separate from destructive repair.
- Planning/design chat continues to refine Issue #56 when material product decisions are made.

## Validation

- PR #61 functional head passed Flutter CI before merge.
- PR #62 passed Flutter CI before merge.
- PR #63 head passed Flutter CI and was superseded only because concurrent Object work advanced `main`.
- Object PR #64 passed final Flutter CI before merge.
- Object PR #65 is merged; detailed validation is recorded in `docs/AI_PROGRESS_OBJECT.md`.
- Relation PR #66 final latest-head CI passed dependency install, Drift generation, `flutter analyze`, and the full test suite before merge.
- Relation PR #69 requires final latest-head CI before merge.

## Known risks

- Parallel work is useful only when file ownership is reasonably separate; otherwise replay narrow lane changes on latest `main` rather than force-merging stale shared handoff files.
- GitHub Actions usage limits may affect CI availability; pending CI alone should not stop independent work.
- Object `GenericDatabasePage` and `core_object_bridge.dart` remain Object-owned integration surfaces even where they call low-level Relation APIs; Relation lane should expose services and hand off adoption rather than create concurrent broad edits.
- Integrity diagnostics are safe to add read-only; ambiguous automatic repair remains a product/data-policy decision and must not be performed routinely.
