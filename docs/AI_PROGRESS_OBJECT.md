# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

Issue #56 now contains the current delivery milestones and implementation order. Treat it as the active product/design contract.

## Current integration state

`main` includes:

- shared Object detail/Body UI, Formula/Rollup rendering, persisted Body editing and Daily Note entry from PR #68;
- shared Relation detail context from PR #76;
- safe Value -> Object and URL -> reusable Weblink execution from PR #77;
- canonical Relation-neighborhood rendering in `ObjectInspectorPage` from PR #78;
- grouped Board Object creation planner/service from PR #79, including Relation-safe grouped initialization through `RelationMutationService`.

PR #79 is **merged**. Any older handoff text describing it as open/pending is stale.

PR #82 (`feature/database-collection-semantics`) is the active core integration dependency for the next Database/View phase. It is owned by the Object/database integration path and currently provides `Database = target ObjectType + collectionFilter` foundations, Database-first membership resolution, separate View projection composition, collection config support, and non-destructive persistence.

PR #83 is closed/unmerged because it was started accidentally after a user stop request. Do not resume that branch as an active implementation path.

## Completed Object-lane foundations

1. **Property semantics**
   - explicit Value / Object Relation / Computed distinction.

2. **ObjectType/default contracts**
   - ObjectType defaults and persisted/default-resolution foundations.

3. **Body / shared detail foundation**
   - versioned/extensible Body persistence;
   - paragraph-safe simple editing that refuses to flatten richer documents;
   - shared Object detail loading/editing/session contracts.

4. **Reusable Object types / promotion**
   - Weblink and Image Object facades;
   - Value -> Object planning/execution;
   - URL -> reusable Weblink promotion with source Value preserved by default.

5. **Daily Note foundation**
   - unique-date open-or-create and shared detail bridge without a special data silo.

6. **Relation consumption in Object UI**
   - Object detail consumes canonical Relation neighborhood/read APIs;
   - outgoing Relations and Backlinks render from the same canonical payload.

7. **Board integration foundation**
   - typed drag/drop grouped mutation support;
   - grouped Object creation planner/service;
   - scalar, Multi-select, Relation, and unassigned presets;
   - Relation groups route through `RelationMutationService`.

## Current phase

The Object lane is now primarily an **integration/UX lane**, not a new-foundation lane.

Priority is to complete Milestones A/B from Issue #56:

- Database collection semantics in the real generic page;
- Board create-in-group real UI;
- canonical Relation picker/editor real UI;
- multi-View Database UX;
- contextual Object opening.

Advanced Body blocks, embedded Views, and richer Daily Note composition should not displace the Database/View core until Milestone A/B is coherent.

## Exact next actions

1. Inspect the latest head and Flutter CI for PR #82. Fix branch-caused failures and merge only when latest-head validation is green (unless explicitly directed otherwise).
2. After #82 lands, integrate `DatabaseCollectionResolver` / Database-first collection membership into `GenericDatabasePage`, then apply View projection as an independent second stage.
3. Preserve legacy databases via the self-type/all-Objects fallback until the user explicitly configures collection semantics.
4. Connect merged `ObjectBoardCreateService` to `ObjectBoardView.onCreateInGroup` in `GenericDatabasePage`: prompt for title, create in selected bucket, reload, and select/open the new Object.
5. Add focused page/widget regression coverage for the real Board-column create path, including a grouped Property preset. Relation presets must remain on the canonical mutation facade.
6. Migrate real Relation picker/editor loading to `RelationTargetService.selectionFor()` (or the current canonical selection API) and writes to `RelationMutationService.setRelation()`.
7. Surface missing target ids / legacy single-cardinality drift as diagnostics. Merely opening/closing a picker must not silently repair or drop persisted Relation values.
8. Expose URL -> Weblink promotion through a narrow Object-owned UI affordance, preserving the scalar URL by default.
9. Implement multiple independent Views per Database and top-tab navigation.
10. Implement duplicate-current View as the default `+` action, blank View as secondary, then rename/reorder/delete/overflow behavior.
11. Complete shared side peek / center peek / full-page Object opening after Database/View navigation state is stable enough to preserve origin context.
12. Continue Daily Note / blocks / embedded Views after the usable Database and multi-View milestones are complete.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Stable Relation APIs available to Object lane include `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`/selection context, and integrity/index services.
- Object-owned UI may consume those APIs but must not duplicate Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Daily Note UI, Value promotion UI, Database collection integration, and View UX are Object-owned surfaces.
- Because `GenericDatabasePage` is now a hotspot, do not allow Relation lane to perform a competing broad refactor there; sequence shared work.

## Validation / known state

- PR #76: merged after green Flutter CI.
- PR #77: merged after analyzer correction and green Flutter CI.
- PR #78: merged after green Flutter CI.
- PR #79: merged; grouped create service is on `main`.
- PR #82: open; always inspect its latest head and latest CI before integration.
- Connector runtime may not provide a local Flutter SDK, so executable validation can be delegated to GitHub CI when needed, but exact failures should be inspected and fixed rather than guessed.

## Risks

- ObjectType and Database remain overlapped in parts of the legacy UI/storage. The new model requires conceptual separation, but migration should remain incremental and non-destructive.
- Database `collectionFilter` and View filters must remain separate in domain, persistence, and execution order.
- User-facing Relation writes must not regress to direct low-level Relation mutations.
- Board Relation-group creation must continue using Relation-safe mutation.
- Rich Body documents must never be flattened by the thin paragraph editor.
- Manual include/exclude collection overrides are deliberately deferred until dynamic collection + multi-View behavior is stable.

## Stop reason for this handoff refresh

This file was refreshed from the planning/design chat because implementation state had advanced beyond its previous checkpoint: PR #79 is merged, Issue #56 now has Milestones A–D and a revised execution order, and PR #82 is the active collection-semantics foundation. No product blocker was introduced by this documentation update.
