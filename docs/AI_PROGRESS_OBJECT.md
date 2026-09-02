# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

Issue #56 is the active product/design contract and contains delivery Milestones A–D.

## Current integration state

`main` includes the major Object/Relation foundations plus the following current Object/Database/View integration:

- PR #79 merged: grouped Board Object creation planner/service, including Relation-safe grouped initialization.
- PR #82 merged as `689c84de46cee1292f7f126eb3d5719658f8d8e8`: Phase-1 `Database = target ObjectType + collectionFilter`, separate persistence, resolver, config service, and Database-first/View-second projection composition. CI #474 passed.
- PR #85 merged: Database collection settings dialog, including target ObjectType selection and collection-filter editing without leaking View state.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: collection-aware page loader preserving Database identity/View scope while sourcing filtered target-ObjectType data. CI #477 passed.
- PR #87 merged as `13e301634c764e252263647e700638d0e06d4e5a`: collection-aware normal/Board Object creation plus canonical Object-owned Relation editor adapter. CI #480 passed.
- PR #88 merged as `2ba2142d13de7e7a3a60cf0de1b7f4dea4bdf878`: duplicate-current and blank View creation service with independent persisted identities. CI #481 passed.
- PR #89 merged as `844c4e213cbf37a40e0760d52cc8590203ec6720`: real `DatabaseViewTabs` now uses duplicate-current as primary `+`, blank View as secondary creation, and scoped rename/reorder/delete management. CI #488 passed.
- PR #90 merged as `1383f5d1f70db53206b3ff5aabf55db2464c316a`: typed View-level Object opening-mode overrides with explicit `View > Database > ObjectType > app` resolution. CI #489 passed.
- PR #91 merged as `f68f50f6c38e891151ab290b5d2102a0937ff17d`: the real Object inspector exposes reversible URL Value -> reusable Weblink promotion, preserving the source URL and using the canonical Relation mutation lifecycle. CI #494 passed.
- PR #92 merged as `183b2e5aef5b495ab89cf700df83008b211798cf`: View settings expose inherited / side peek / center peek / full page opening-mode overrides. Initial CI #495 failed only because newly used `RadioListTile` APIs are deprecated under Flutter 3.47; commit `39b06067f257e337060e8bc7b299f6cc6f6cee76` replaced them with non-deprecated controls, and CI #498 passed before merge.
- PR #93 merged as `6c6421967ebeb1fb78a129af912b623df40a8ae5`: the full-page Object inspector now uses `ObjectDetailEditService` for custom Object title edits and basic text/URL/number Value edits while keeping Relation/Computed/system editing conservative. CI #497 passed.

PR #83 remains closed/unmerged and is not an active implementation branch.

## Completed checkpoints in the latest sustained run

1. **Completed adopted multi-View creation and management UX**
   - Added `DatabaseViewManagementService` so rename/reorder/delete remain inside one workspace/Database scope.
   - Reorder requires the complete View set exactly once; stale/cross-scope payloads fail before writes.
   - User-facing deletion preserves at least one View.
   - `DatabaseViewTabs` `+` duplicates the active View; `空のViewを作成` remains the secondary path.
   - Widget regression coverage proves duplicate-current copies independent layout/filter/settings and blank creation starts from Database defaults.
   - PR #89 CI #488 passed before merge.

2. **Added typed View Object opening-mode semantics and UI**
   - `DatabaseViewOpenModeService` persists `sidePeek` / `centerPeek` / `fullPage` without disturbing unrelated View settings.
   - Resolution explicitly follows `View > Database > ObjectType > app fallback`.
   - Clearing the View override restores inheritance instead of copying fallback state.
   - Per-View settings now expose `Objectの開き方` with inherited/default, side peek, center peek, and full page choices.
   - Malformed persisted values fail closed and surface an error rather than being silently rewritten.
   - Fixed CI #495 analyzer deprecations caused by `RadioListTile` by replacing them with non-deprecated `ListTile` controls; corrected CI #498 passed before PR #92 merge.
   - PR #90 CI #489 and PR #92 CI #498 passed.

3. **Exposed reversible URL -> Weblink promotion in real Object detail**
   - Custom URL Value Properties show a narrow `Weblinkに昇格` affordance.
   - Promotion reuses the existing `WeblinkValuePromotionService`, preserves the scalar URL, reuses an existing Weblink Object where applicable, and delegates Relation writes to the stable mutation facade.
   - After promotion the inspector reloads so the newly-created/reused Weblink Relation appears immediately.
   - Widget integration coverage verifies original URL preservation plus Weblink creation/reuse linkage through an Object Relation.
   - PR #91 CI #494 passed before merge.

4. **Moved basic Object inspector editing onto the shared detail mutation service**
   - Custom Object titles can be renamed from the real full-page inspector.
   - Custom text, URL, and number Value Properties can be edited through `ObjectDetailEditService`.
   - Relation and Computed Properties remain read-only in this slice; system Object editing remains conservative.
   - URL editing coexists with the Weblink-promotion affordance.
   - Widget integration coverage proves persisted title/text/number edits through the real inspector.
   - PR #93 CI #497 passed before merge.

5. **Kept the main Database integration hotspot isolated**
   - No Relation lifecycle/index implementation was changed.
   - No broad `GenericDatabasePage` whole-file replacement was attempted after confirming the current GitHub write surface lacks a safe patch primitive for this large file.
   - Independent Object-owned slices were advanced instead of waiting on CI or forcing a risky broad replacement.

## Exact next actions

1. Refresh `GenericDatabasePage` from latest `main` in a patch-capable implementation environment.
2. Wire `GenericDatabaseCollectionPageLoader` into `_reload()` so Database-level membership resolves first and existing View projection remains the second stage.
3. Replace legacy `_createRecord` assumptions with `GenericDatabaseObjectCreateService`, so creation always targets the collection ObjectType.
4. Connect `ObjectBoardView.onCreateInGroup` to `GenericDatabaseObjectCreateService.createInGroup()`: prompt for title, create, reload, and select/open the new Object.
5. Migrate the real Relation picker/editor onto `ObjectRelationEditorService`; surface missing target ids/cardinality drift without silent repair.
6. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
7. Add focused page/widget regression coverage for collection-aware reload/create/Relation edit paths.
8. Consume `DatabaseViewOpenModeService.resolve()` when opening Objects from a View; then add actual side-peek / center-peek / full-page routing while preserving Database/View context.
9. Implement View overflow handling for many top tabs; core create/rename/reorder/duplicate/delete and opening-mode configuration are now integrated.
10. Extend shared Object detail editing to additional typed Value editors (checkbox/select/multi-select/date/rating) without routing Relation or Computed writes through the Value editor.
11. Continue Daily Note and Body/Block work through generic Object/Relation/detail mechanisms after Milestone A page integration is stable.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Stable Relation APIs consumed by Object UI include `RelationMutationService`, `RelationReadService.neighborhood()`, and `RelationTargetService.selectionFor()`.
- Object UI must not duplicate Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion UI and multi-View UX are Object-owned surfaces.
- `GenericDatabasePage` remains the main integration hotspot; avoid competing broad Relation-lane edits there.

## Validation

- PR #82 Flutter CI #474: success.
- PR #86 Flutter CI #477: success.
- PR #87 Flutter CI #480: success.
- PR #88 Flutter CI #481: success.
- PR #89 Flutter CI #488: Drift generation, `flutter analyze`, full tests — success.
- PR #90 Flutter CI #489: Drift generation, `flutter analyze`, full tests — success.
- PR #91 Flutter CI #494: Drift generation, `flutter analyze`, full tests — success.
- PR #92 Flutter CI #495: failed only on analyzer deprecation infos introduced by the branch; corrected immediately.
- PR #92 corrected Flutter CI #498: Drift generation, `flutter analyze`, full tests — success.
- PR #93 Flutter CI #497: Drift generation, `flutter analyze`, full tests — success.
- The current connector runtime does not expose a local Flutter SDK; executable validation is delegated to GitHub CI and exact workflow logs.

## Risks / blockers

- No product/design blocker is active.
- The main remaining Milestone A risk is the legacy assumption inside `GenericDatabasePage` that Database id and ObjectType id are the same; merged loader/create adapters are designed to remove it incrementally.
- The current GitHub write surface replaces existing files as a whole. `GenericDatabasePage` is large enough that broad replacement without a reliable patch/edit primitive is an avoidable corruption/merge risk; prefer a patch-capable implementation environment for that hotspot.
- User-facing Relation writes must not regress to low-level direct Relation mutation.
- Board Relation-group creation must continue through `RelationMutationService` via the existing Board create service.
- View opening-mode settings are persisted and user-editable, but the actual View-to-detail navigation path does not yet consume them.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

This run completed and validated multiple safe checkpoints, merging PRs #89, #90, #91, #92 and #93. CI failures caused by this run were fixed (#92 deprecation-only analyzer failure), and all merged latest heads are green. The remaining highest-priority Milestone A work now converges on the large `GenericDatabasePage` integration hotspot: collection-aware reload/create, Board create UI, canonical Relation picker, collection settings, and View open-mode consumption. In this runtime, writes to that file require whole-file replacement and a reliable patch/edit primitive is not available, so continuing there would create avoidable corruption/merge risk. Independent narrow View/Object-detail slices that were immediately actionable were advanced during this run; the next implementation run should prioritize the page wiring in a patch-capable environment rather than continue running ahead into lower-priority Milestone C/D work.
