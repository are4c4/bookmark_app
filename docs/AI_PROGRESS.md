# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - reusable Object types
   - Object detail content and Body/block model
   - Daily Notes and Value-to-Object promotion

2. **Relation lane** — `docs/AI_PROGRESS_RELATION.md`
   - Relation/backlink lifecycle
   - bidirectional Relation integrity
   - relation write validation and source/target constraints
   - rename/delete propagation and Relation APIs

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only.

## Sustained-run policy

Implementation runs do not stop after one small PR/commit/checkpoint while safe Issue #56 work remains. Pending CI alone is not a blocker; continue with non-dependent work. Stop only for a genuine design/risk/cross-lane blocker, unavailable external infrastructure with no independent work remaining, or a runtime/tool/session limit.

## Latest relevant state

- `main` is at `6770a5f` after Relation PR #66 merged.
- PR #61 merged Value / Object Relation / Computed semantics.
- PR #62 merged bidirectional Relation pair integrity hardening.
- PR #64 merged Value-to-Object planning, Body contracts, ObjectType defaults contract, and shared Object detail content.
- PR #65 merged Object Body/defaults persistence, Weblink Object, Daily Note open-or-create, Object detail loading, and safe paragraph Body adaptation. Its final CI passed.
- PR #66 merged stable Relation mutation/read/index APIs, source/target validation, bidirectional lifecycle hardening, Relation-safe Object deletion, and Tag hierarchy cleanup. Its final CI passed.
- Object PR #67 is open with shared Object detail editing/session/default-resolution/Image facade work; its head passed CI but needs replay/rebase because `main` advanced concurrently.
- Object PR #68 is open with actual Object inspector integration, reusable Body UI, and today/Daily Note navigation; latest corrective CI is running.
- Object PR #70 is open with generic Value-to-Object execution plus URL -> reusable Weblink promotion built on the merged Relation mutation facade; a follow-up analyzer correction is awaiting fresh CI.
- Issue #56 remains the shared implementation contract.

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
- Rebase/replay stale branches rather than force-merging shared handoff conflicts.
- Preserve existing bookmark data and behavior; no destructive migrations without explicit approval.

## Next repository-wide actions

- Object lane: finish CI correction/integration for #68 and #70, then replay the already-green #67 onto the newest `main` without restoring stale handoff text.
- Relation lane: continue from `docs/AI_PROGRESS_RELATION.md`; Object consumers should now use the stable Relation facades merged in #66 rather than low-level lifecycle duplication.
- After Object detail/session pieces land, converge side/center/full-page containers on one Object-owned content/session layer, with Database/View presentation overrides remaining above it.
- Planning/design chat continues to refine Issue #56 for material product decisions.

## Validation

- PR #65 final Flutter CI succeeded.
- PR #66 final Flutter CI #390 succeeded before merge.
- PR #67 head Flutter CI #395 succeeded.
- PR #68 corrective CI is pending/running after an initial test-only failure; its analyzer passed on the failed run.
- PR #70 received an analyzer correction after CI #402 failed before tests; newest CI is pending.

## Known risks

- PR #67 is stale only because concurrent work advanced `main`; replay its Object-owned files carefully after #68/#70 rather than forcing shared progress-file conflicts.
- GitHub Actions usage/queueing may delay validation; pending CI alone should not stop independent implementation.
- Block-editor scope can expand quickly; retain the current block-safe persistence contract and thin paragraph editing until richer block UX is deliberately scheduled.
