# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric detail UX, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion. Relation lifecycle/integrity remains in the Relation lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current repository state

- `main` is at `6770a5f` after Relation PR #66 merged.
- PR #65 (`Persist Object Body and ObjectType defaults`) merged at `93d8cf1`; its final Flutter CI #372 passed.
- Relation PR #66 (`Harden Relation lifecycle and stable APIs`) merged; its final Flutter CI #390 passed.
- Object PR #67 (`Add shared Object detail editing and Daily Note bridge`) is open on an older base. Its head `6a87707` passed Flutter CI #395 but needs replay/rebase because `main` advanced concurrently. It owns shared detail edit/session/default-resolution and Image Object facade files; do not duplicate those files.
- Object PR #68 (`Integrate shared Object detail content into inspector`) is open on `feature/object-detail-body-ui`.
- Object PR #70 (`Execute Value to Object promotion safely`) is open on `feature/object-value-promotion-execution` from current post-#66 `main`.

## Checkpoints completed in the latest sustained run

1. **Shared Object detail payload integrated into the existing inspector**
   - `ObjectInspectorPage` now loads through `ObjectDetailContentLoader` instead of assembling stored Object data independently.
   - Formula/Rollup values are rendered through `ObjectDetailContent.valueFor`, keeping computed values out of ordinary persisted Properties.

2. **Reusable safe Body detail surface**
   - Added `ObjectBodySection` as a reusable presentation/editor widget.
   - Paragraph-only Body documents can be displayed/edited through the existing safe plain-text adapter and `ObjectBodyStore`.
   - Documents containing richer/unknown blocks are protected from simplified editing instead of being flattened.
   - Added widget coverage for paragraph editing, empty-Body affordance, and rich-block protection.

3. **Daily Note entry through normal Object navigation**
   - Added a “today” action to the Object inspector.
   - It calls `DailyNoteService.openOrCreate` and opens the result through the same `ObjectInspectorPage`; no special Daily Note editor or data silo was introduced.

4. **Value -> Object execution layer after Relation #66**
   - Added `ObjectValuePromotionExecutionService`.
   - Revalidates source/target ObjectTypes, source Property semantics, source Object ownership, and stale-plan state before mutation.
   - Preserves the source Value by default.
   - `clearAfterLink` requires explicit destructive confirmation and clears only after a successful Relation write.
   - Creates or reuses a compatible Relation Property and delegates the actual write to Relation-lane `RelationMutationService`.
   - Rolls back a newly-created target Object / Relation Property when linking fails.
   - Supports linking an existing target Object to compose with reusable Object facades.

5. **End-to-end URL Value -> Weblink promotion**
   - Added `WeblinkValuePromotionService` combining Weblink planning + `findOrCreate` + generic promotion execution.
   - Repeated promotion of the same normalized URL reuses the existing Weblink Object, preserves the scalar URL, and does not duplicate Relation targets.

## Validation

- PR #65 final head: Flutter CI #372 **success**.
- Relation PR #66 final head: Flutter CI #390 **success**.
- Concurrent Object PR #67 head `6a87707`: Flutter CI #395 **success**.
- PR #68 first full head `c7dda3a`: `flutter analyze` passed, tests failed in CI #398. A follow-up test-stability commit `6e1b7d5` sets an explicit widget-test viewport; CI #406 is currently running on that head.
- PR #70 head `dd4f46e`: CI #402 failed during `flutter analyze` before tests. Follow-up commit `29d038e` makes the resolved promotion Relation explicitly non-null at the mutation boundary; newest CI is pending/not yet registered at this handoff.
- This connector session has no local Flutter runtime, so executable validation uses PR CI.

## Exact next actions

1. Check CI #406 / latest PR #68 head `6e1b7d5`. If green and mergeable, integrate #68; if tests still fail, inspect the failing test check and simplify only the flaky widget interaction while retaining adapter/data-safety coverage.
2. Check the newest PR #70 CI after `29d038e`. If analyzer still fails, inspect check annotations and fix the exact diagnostic; then run full tests via CI.
3. Once #70 is green, merge it before building any promotion UI. Keep generic executor logic separate from presentation confirmation flows.
4. Replay/rebase the already-green PR #67 onto latest `main` after #68/#70 integration, preserving its Object-detail edit/session/default-resolution/Image facade work and resolving only real overlap.
5. After the shared Object detail/session pieces are integrated, route side/center/full-page containers through the same Object-owned session/content layer while leaving Database/View chrome outside.
6. Add user-facing Value -> Object promotion affordances first for URL -> Weblink (low ambiguity), with preview/confirmation for any destructive source clear.
7. Continue to keep Tag hierarchy mutation, backlink lifecycle, bidirectional integrity, and Relation index repair in the Relation lane.

## Cross-lane boundaries

- Relation PR #66 is now the stable source of Relation mutation/read/index APIs. Object promotion consumes `RelationMutationService` rather than reimplementing integrity logic.
- Do not modify `object_store.dart`, `bidirectional_relation_store.dart`, or Relation lifecycle code from the Object lane unless a narrowly-scoped integration defect requires it.
- PR #67 currently touches `docs/AI_PROGRESS.md` and this handoff on a stale base; when replaying it, prefer the newest handoff text rather than restoring stale progress state.

## Risks / notes

- PR #68 and #67 both concern Object detail architecture but currently own different implementation files; integrate/replay in sequence rather than broad-merging stale branches.
- Weblink `findOrCreate` handles normal sequential reuse but is not a database-level concurrency uniqueness constraint.
- The generic promotion executor validates stale source values before creating/linking, but future UI should still preview the action and make destructive clearing explicit.

## Stop reason

The run completed well beyond the minimum checkpoint target: inspector integration, reusable Body UI/tests, Daily Note navigation, generic Value-to-Object execution, and Weblink promotion composition. Remaining immediate work is executable CI correction/integration on #68/#70 plus replaying the concurrently developed, already-green #67 onto the newly advanced `main`; these states are recorded above so the next Object run can resume without chat context.
