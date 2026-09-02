# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric detail UX, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion. Relation lifecycle/integrity remains in the Relation lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current repository state

- `main` is at `6770a5f` after Relation PR #66 merged.
- PR #65 (`Persist Object Body and ObjectType defaults`) merged at `93d8cf1`; final Flutter CI #372 passed.
- Relation PR #66 (`Harden Relation lifecycle and stable APIs`) merged; final Flutter CI #390 passed.
- Object PR #67 (`Add shared Object detail editing and Daily Note bridge`) is open on an older base. Its head `6a87707` passed Flutter CI #395 but needs replay/rebase because `main` advanced concurrently. It owns shared detail edit/session/default-resolution and Image Object facade files; do not duplicate those files.
- Object PR #68 (`Integrate shared Object detail content into inspector`) is open on `feature/object-detail-body-ui`; latest head is `447f1ba` after fixing the Body editor controller lifecycle and restoring interaction regression coverage.
- Object PR #70 (`Execute Value to Object promotion safely`) is open on `feature/object-value-promotion-execution`; latest code head before this handoff update is `6ec05d1` after removing analyzer-redundant non-null assertions.

## Checkpoints completed in the latest sustained run

1. **Shared Object detail payload integrated into the existing inspector**
   - `ObjectInspectorPage` now loads through `ObjectDetailContentLoader` instead of assembling stored Object data independently.
   - Formula/Rollup values are rendered through `ObjectDetailContent.valueFor`, keeping computed values out of ordinary persisted Properties.

2. **Reusable safe Body detail surface**
   - Added `ObjectBodySection` as a reusable presentation/editor widget.
   - Paragraph-only Body documents can be displayed/edited through the existing safe plain-text adapter and `ObjectBodyStore`.
   - Documents containing richer/unknown blocks are protected from simplified editing instead of being flattened.
   - CI exposed a real controller lifecycle bug: the original local `TextEditingController` could be disposed while the closing dialog route still referenced it.
   - Fixed production code by moving controller ownership into a stateful dialog and disposing it with the dialog State lifecycle.
   - Restored end-to-end widget interaction coverage for open/edit/save/close, plus empty-Body and rich-block protection coverage.

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
- PR #68: analyzer passed on both CI #398 and #406. CI #406 failed tests because the Body editor disposed its controller before the closing route had fully released the TextField. That production lifecycle defect is fixed at `01f5db2`; interaction regression coverage was restored at `447f1ba`. Fresh CI #423 is queued/running for the latest head.
- PR #70: CI #414 exposed only two `unnecessary_non_null_assertion` analyzer warnings. They were removed, but a concurrent stale correction commit briefly restored the assertions; latest `6ec05d1` reapplies the exact analyzer fix. Fresh CI should be checked on the latest branch head after this handoff commit.
- This connector session has no local Flutter runtime, so executable validation uses PR CI and exact workflow job logs.

## Exact next actions

1. Check latest PR #68 CI for head `447f1ba` (or newer). If green and mergeable, integrate #68. If it fails, inspect the exact workflow job log before changing code.
2. Check latest PR #70 CI after `6ec05d1` plus this handoff commit. The known analyzer warnings should be gone; if tests fail, fetch the job log and fix the exact failing test.
3. Once #70 is green, merge it before building promotion UI. Keep generic executor logic separate from presentation confirmation flows.
4. Replay/rebase the already-green PR #67 onto latest `main` after #68/#70 integration, preserving its Object-detail edit/session/default-resolution/Image facade work and resolving only real overlap.
5. After shared Object detail/session pieces are integrated, route side/center/full-page containers through the same Object-owned session/content layer while leaving Database/View chrome outside.
6. Add user-facing Value -> Object promotion affordances first for URL -> Weblink (low ambiguity), with preview/confirmation for any destructive source clear.
7. Continue to keep Tag hierarchy mutation, backlink lifecycle, bidirectional integrity, and Relation index repair in the Relation lane.

## Cross-lane boundaries

- Relation PR #66 is now the stable source of Relation mutation/read/index APIs. Object promotion consumes `RelationMutationService` rather than reimplementing integrity logic.
- Do not modify `object_store.dart`, `bidirectional_relation_store.dart`, or Relation lifecycle code from the Object lane unless a narrowly-scoped integration defect requires it.
- PR #67 currently touches `docs/AI_PROGRESS.md` and this handoff on a stale base; when replaying it, prefer the newest handoff text rather than restoring stale progress state.
- Concurrent Object work may update an active branch while CI is running. Re-read branch head before applying a fix and do not assume an earlier head remains current.

## Risks / notes

- PR #68 and #67 both concern Object detail architecture but currently own different implementation files; integrate/replay in sequence rather than broad-merging stale branches.
- Weblink `findOrCreate` handles normal sequential reuse but is not a database-level concurrency uniqueness constraint.
- The generic promotion executor validates stale source values before creating/linking, but future UI should still preview the action and make destructive clearing explicit.

## Stop reason

This sustained run completed multiple independent checkpoints and then followed CI failures to their exact causes rather than stopping at pending/failed checks: inspector/content integration, reusable Body UI, a production dialog-controller lifecycle repair with regression coverage, Daily Note navigation, generic Value-to-Object execution, and Weblink promotion composition. Immediate remaining work is fresh CI completion/integration for #68/#70 and replaying the already-green #67 onto the newest main; exact continuation state is recorded above.
