# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current integration state

- `main` includes PR #68 at merge commit `c112f165ffbda7b032fd51426579cfdc4325de0e`.
- PR #76 (`feature/object-detail-relation-context-v2`) is open on that `main` and composes shared Object detail state with the canonical Relation `neighborhood()` API.
- PR #77 (`feature/object-value-promotion-execution-v2`) is open on that `main` and replays safe Value -> Object execution plus URL -> reusable Weblink promotion.
- Superseded stale Object PRs #70 and #72 are closed; do not resume them.

## Checkpoints completed in the latest run

1. **Landed Object detail/Body UI integration**
   - Verified PR #68 head `447f1babac5ee9774098923c87a207b522321273` passed Flutter CI #423.
   - Squash-merged #68 into `main` as `c112f165ffbda7b032fd51426579cfdc4325de0e`.
   - `ObjectInspectorPage` now consumes shared Object detail content, shows Formula/Rollup values and persisted Body, supports paragraph-safe Body editing, and exposes today's Daily Note through general Object navigation.

2. **Replayed Object detail Relation context on latest main**
   - Created PR #76 from current `main` rather than force-merging stale #72.
   - Added `ObjectDetailRelationContext` and loader.
   - Uses merged Relation PR #73's `RelationReadService.neighborhood()` as one canonical outgoing + backlink payload.
   - Keeps Relation lifecycle/index logic out of Object-owned code.
   - Added focused regression coverage for both outgoing and incoming Relation context.
   - PR #76 CI #434 is currently in progress.

3. **Replayed safe Value -> Object execution on latest main**
   - Created PR #77 from current `main` rather than force-merging stale #70.
   - Added `ObjectValuePromotionExecutionService` using `RelationMutationService` for canonical Relation writes.
   - Preserves source Value by default; stale plans fail before target creation; destructive source clearing still requires explicit confirmation.
   - Supports existing-target linking and rollback of newly-created records on link failure.
   - Added `WeblinkValuePromotionService` so repeated URL promotion reuses the same Weblink Object while preserving the scalar URL.
   - Added focused execution and Weblink-reuse tests.
   - PR #77 CI #435 is currently in progress.

## Validation

- PR #68 Flutter CI #423: success before merge.
- PR #76 Flutter CI #434: in progress at handoff.
- PR #77 Flutter CI #435: in progress at handoff.
- This connector runtime does not provide a local Flutter SDK, so executable analyze/tests are delegated to PR CI.

## Exact next actions

1. Inspect final CI for PR #76; if green, merge it. If failures are caused by this slice, fix them first.
2. Inspect final CI for PR #77; if green, merge it after refreshing mergeability against whatever lands first. Replay rather than force-merge if `main` advances into a real conflict.
3. After #76 lands, connect resolved Relation neighborhood data to an existing shared Object detail presentation surface without duplicating graph queries.
4. After #77 lands, expose Value -> Object promotion through a narrow Object-owned UI/service entry point; preserve the source Value by default and require explicit confirmation for destructive clearing.
5. Use `RelationTargetService` from merged PR #75 when implementing Relation picker/editing surfaces; do not duplicate target validation in Object UI.
6. Continue Daily Note through general Object detail/Relation mechanisms; avoid a special note data silo.
7. Continue Issue #56 Object-centric Database/View integration only where it does not conflict with Relation-owned lifecycle code.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, and Tag hierarchy mutation stay in `docs/AI_PROGRESS_RELATION.md`.
- Stable Relation APIs available to Object lane: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`, and integrity/index services for diagnostics/reconciliation.
- Object detail UI, Daily Note UI, Value promotion UI, and `core_object_bridge.dart` remain Object-owned synchronization surfaces.

## Blockers / risks

- #76 and #77 require latest-head CI before merge.
- Both PRs started from the same `c112f165...` base; whichever merges first may advance `main`. Re-check mergeability for the other and replay only if necessary.
- Do not auto-repair ambiguous persisted Relation values; Relation lane intentionally supports only deterministic index reconciliation.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

The run completed multiple safe checkpoints: merged validated #68, replayed stale Relation-context work as #76 using the newer neighborhood API, and replayed stale Value-promotion work as #77 on current main. Both new PRs are now in executable CI. Further integration of these exact slices depends on their latest-head validation; the next independent Object work should avoid editing the same new files until CI reports whether fixes are required.
