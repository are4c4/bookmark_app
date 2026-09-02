# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

The implementation is split into two concurrent-capable lanes:

1. **Database / View lane** — `docs/AI_PROGRESS_DB_VIEW.md`
   - Database collection semantics
   - Database/View separation
   - Filter/Sort/Group/layout integration
   - multiple Views and top-tab navigation
   - Gallery/List/Table/Board projection and database-page UX

2. **Object / Relation lane** — `docs/AI_PROGRESS_OBJECT_RELATION.md`
   - Object/ObjectType/Property architecture
   - Value vs Object Relation semantics
   - Tag-as-Object, reusable Object types, backlinks
   - Object detail content, Body/block model
   - Daily Notes and time-based Object patterns

Each implementation chat/run should pick one primary lane and update only its matching progress file unless repository-wide integration state changes.

## Latest relevant state

- `main` includes the persistent AI handoff workflow and now the two-lane development model.
- Existing generic foundations include Object query/filter/sort, grouping, Board view, Board drag/drop persistence, Formula/Rollup, bidirectional Relations, ObjectType templates, and ObjectType management.
- PR #54 reusable Object view toolbar is merged.
- PR #57 generic Object view coordinator is merged.
- PR #59 integrates Object view controls/layouts into `GenericDatabasePage` and is merged.
- PR #60 is open for grouped-property presets when creating Objects from Board columns; its next integration step belongs to the Database/View lane.
- Object / Relation lane is implementing an explicit domain semantic split between lightweight Value properties, Object Relations, and computed properties on `feature/object-property-semantics`.
- Issue #56 contains the current product/design decisions and remains the shared implementation contract.

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
- Use focused lane-specific branches/PRs.
- Avoid both lanes concurrently owning broad refactors of the same core file.
- If a change crosses lanes, document the dependency and sequence the overlapping work where practical.
- Rebase/refresh from latest `main` before merging overlapping foundation changes.
- Preserve existing bookmark data and behavior; no destructive migrations without explicit approval.

## Next repository-wide actions

- Database / View lane resumes from `docs/AI_PROGRESS_DB_VIEW.md`, including PR #60 and Database collection/multi-View work.
- Object / Relation lane validates and lands `feature/object-property-semantics`, then proceeds to promotion/default/detail/body foundations without editing database-page UX.
- Planning/design chat continues to refine Issue #56 when material product decisions are made.
- Integrate lane PRs into `main` in small, validated slices.

## Validation

Feature runs must record exact Flutter analyze/test results in their lane progress files. GitHub Actions capacity may be limited; when executable CI is unavailable, record static/review validation explicitly and avoid claiming tests passed.

## Known risks

- Parallel work is useful only when file ownership is reasonably separate; otherwise sequence the slices.
- GitHub Actions usage limits may affect CI availability; record local/static validation when CI is unavailable.
- Block-editor and migration work can expand quickly; keep the initial slices narrow and backward-compatible.
- Value-to-Object promotion and Tag-as-Object migration must not destroy existing scalar/tag data before compatibility paths are proven.
