# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

Issue #56 is the active product/design contract and contains delivery Milestones A–D.

## Current integration state

`main` includes the major Object/Relation foundations plus the following current Database/View work:

- PR #79 merged: grouped Board Object creation planner/service, including Relation-safe grouped initialization.
- PR #82 merged as `689c84de46cee1292f7f126eb3d5719658f8d8e8`: Phase-1 `Database = target ObjectType + collectionFilter`, separate persistence, resolver, config service, and Database-first/View-second projection composition. CI #474 passed.
- PR #85 merged: Database collection settings dialog, including target ObjectType selection and collection-filter editing without leaking View state.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: collection-aware page loader preserving Database identity/View scope while sourcing filtered target-ObjectType data. CI #477 passed.
- PR #87 merged as `13e301634c764e252263647e700638d0e06d4e5a`: collection-aware normal/Board Object creation plus canonical Object-owned Relation editor adapter. CI #480 passed.
- PR #88 merged as `2ba2142d13de7e7a3a60cf0de1b7f4dea4bdf878`: duplicate-current and blank View creation service with independent persisted identities. CI #481 passed.
- PR #89 merged as `844c4e213cbf37a40e0760d52cc8590203ec6720`: `DatabaseViewTabs` now uses duplicate-current as the primary `+` action, exposes `空のViewを作成` as the secondary path, and routes rename/reorder/delete through a scoped management facade. CI #488 passed Drift generation, analyze, and tests.
- PR #90 merged as `1383f5d1f70db53206b3ff5aabf55db2464c316a`: typed View-level Object opening-mode overrides with explicit `View > Database > ObjectType > app` resolution. CI #489 passed Drift generation, analyze, and tests.

PR #83 remains closed/unmerged and is not an active implementation branch.

## Completed checkpoints in the latest sustained run

1. **Completed adopted multi-View creation UX in real tabs**
   - Added `DatabaseViewManagementService` so user-facing rename/reorder/delete operations remain within one workspace/Database scope.
   - Reorder requires the complete View set exactly once; stale/cross-scope payloads fail before writes.
   - User-facing deletion preserves at least one View.
   - `DatabaseViewTabs` `+` now duplicates the active View directly, matching the adopted design.
   - A secondary create menu exposes `空のViewを作成`.
   - Per-View duplicate uses the same `DatabaseViewCreationService` path.

2. **Added real tab/widget regression coverage**
   - Widget coverage proves `+` duplicates layout/filter/settings into a new View identity and selects it.
   - The secondary menu creates a blank View from Database defaults and selects it.
   - Management tests cover rename normalization, exact-scope reorder, last-View protection, and stale scope rejection.
   - PR #89 Flutter CI #488 passed before squash merge.

3. **Added typed View Object opening-mode overrides**
   - `DatabaseViewOpenModeService` persists `sidePeek` / `centerPeek` / `fullPage` in View settings without disturbing unrelated settings.
   - Resolution explicitly follows the adopted precedence `View > Database > ObjectType > app fallback`.
   - Clearing the View override restores inheritance rather than eagerly copying a fallback.
   - Unknown persisted values fail closed.
   - PR #90 Flutter CI #489 passed before squash merge.

4. **Kept the main integration hotspot isolated**
   - No Relation lifecycle/index implementation was changed.
   - No broad `GenericDatabasePage` rewrite was mixed into the multi-View slices.
   - An attempt to obtain a safe patchable full-file representation for the large page through the current runtime was not reliable enough to justify a whole-file replacement.

## Exact next actions

1. Refresh `GenericDatabasePage` from latest `main` in an environment that can patch the large file safely.
2. Wire `GenericDatabaseCollectionPageLoader` into `_reload()` so Database-level membership resolves first and existing View projection remains the second stage.
3. Replace legacy `_createRecord` assumptions with `GenericDatabaseObjectCreateService`, so creation always targets the collection ObjectType.
4. Connect `ObjectBoardView.onCreateInGroup` to `GenericDatabaseObjectCreateService.createInGroup()`: prompt for title, create, reload, and select/open the new Object.
5. Migrate the real Relation picker/editor onto `ObjectRelationEditorService`; surface missing target ids/cardinality drift without silent repair.
6. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
7. Add focused page/widget regression coverage for collection-aware reload/create/Relation edit paths.
8. Add a View settings affordance for `DatabaseViewOpenModeService`, then consume the resolved mode when opening Objects from a View.
9. Implement View overflow handling for many top tabs; core create/rename/reorder/duplicate/delete behavior is now integrated.
10. Expose URL -> reusable Weblink promotion through a narrow Object-owned affordance while preserving the source URL by default.
11. Continue side peek / center peek / full-page shared Object detail after Database/View navigation state is stable.

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
- PR #89 Flutter CI #488: dependency install, Drift generation, `flutter analyze`, full tests — success before merge.
- PR #90 Flutter CI #489: dependency install, Drift generation, `flutter analyze`, full tests — success before merge.
- The current connector runtime does not expose a local Flutter SDK; executable validation is delegated to GitHub CI.

## Risks / blockers

- No product/design blocker is active.
- The main remaining Milestone A risk is the legacy assumption inside `GenericDatabasePage` that Database id and ObjectType id are the same; merged loader/create adapters are designed to remove it incrementally.
- The current GitHub write surface replaces an existing file as a whole. `GenericDatabasePage` is large enough that broad replacement without a reliable patch/edit primitive is an avoidable corruption/merge risk; prefer a patch-capable implementation environment for that hotspot.
- User-facing Relation writes must not regress to low-level direct Relation mutation.
- Board Relation-group creation must continue through `RelationMutationService` via the existing Board create service.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

This run completed multiple independent safe checkpoints and merged two green PRs (#89 and #90). The highest-priority remaining Milestone A work is concentrated in the large `GenericDatabasePage` integration hotspot. In this runtime, existing-file writes require whole-file replacement and a reliable full-file patch path was not available, so continuing that broad page edit would add avoidable corruption/merge risk. Independent multi-View and opening-mode foundation work was completed instead; the next run should use a patch-capable environment for the page wiring, or continue another narrow Object-owned slice that does not require broad replacement.
