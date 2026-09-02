# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

The product direction remains: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

Issue #56 contains the current execution roadmap and delivery Milestones A–D. Treat it as the product/design contract.

## Development lanes

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - Object-centric Database/View integration
   - reusable Object types
   - Object detail content/opening
   - Body/block model
   - Daily Notes and Value-to-Object promotion

2. **Relation lane** — `docs/AI_PROGRESS_RELATION.md`
   - Relation/backlink lifecycle
   - bidirectional Relation integrity
   - relation write validation and source/target constraints
   - rename/delete propagation and stale metadata handling
   - stable Relation APIs consumed by Object surfaces

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only.

## Current implementation position

The active phase is **Database/View integration and user-facing UX**. Most Object/Relation primitives are already available and should be consumed rather than reimplemented.

### Integrated Object / database foundations on `main`

- PR #61: Value / Object Relation / Computed Property semantics.
- PR #64: Value-to-Object planning, versioned Body blocks, ObjectType defaults contract, shared Object detail contracts.
- PR #65: Body/default persistence, Weblink Object service, Daily Note open-or-create, shared detail loading, paragraph-safe Body adapter.
- PR #68/#71/#76/#77/#78: shared Object detail/editing, persisted Body, Daily Note bridge, reusable Image/Weblink flows, canonical Relation neighborhood consumption, safe Value -> Object execution.
- PR #79: grouped Board Object creation planner/service merged, including Relation-safe presets.
- PR #82 merged as `689c84de46cee1292f7f126eb3d5719658f8d8e8`: Phase-1 `Database = target ObjectType + collectionFilter`, separate persistence, collection resolver/config service, and Database-first/View-second projection composition. CI #474 passed.
- PR #85: Database collection settings dialog for target ObjectType and collection-filter editing, independent from View configuration.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: collection-aware page loader preserving Database identity/View scope while sourcing filtered target-ObjectType data. CI #477 passed.
- PR #87 merged as `13e301634c764e252263647e700638d0e06d4e5a`: collection-aware normal/Board Object creation plus canonical Object-owned Relation editor adapter. CI #480 passed.
- PR #88 merged as `2ba2142d13de7e7a3a60cf0de1b7f4dea4bdf878`: adopted dual-path View creation service with independent persisted View identities. CI #481 passed.
- PR #89 merged as `844c4e213cbf37a40e0760d52cc8590203ec6720`: real `DatabaseViewTabs` now uses duplicate-current as primary `+`, blank View as secondary creation, and scoped rename/reorder/delete management. CI #488 passed.
- PR #90 merged as `1383f5d1f70db53206b3ff5aabf55db2464c316a`: typed View-level Object opening-mode override persistence and `View > Database > ObjectType > app` resolution. CI #489 passed.

### Integrated Relation foundations on `main`

- PR #62/#66/#69/#73/#74/#75/#80/#81: canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, canonical picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.

PR #83 remains closed/unmerged and is not an active implementation path.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = what the Object is: schema + defaults.
- Database = which Objects: target ObjectType + collection semantics.
- View = how to see/narrow/present a Database collection.
- Database collection filtering and View filtering are separate pipeline stages and separate persistence concerns.
- Effective defaults resolve as `View override > Database override > ObjectType default > app fallback`.
- Object content = structured Properties + free Body designed for blocks.
- Property semantics distinguish Value, Object Relation, and computed properties.
- Tags are Objects; Select/MultiSelect remain for local option sets.
- Date is a Value; Daily Note is an Object keyed by a unique date.
- Object detail presentation should reuse shared content across side peek, center peek, and full page.

## Delivery milestones

### Milestone A — Usable Object Database
Complete collection semantics in the real page, collection-aware creation, Board create-in-group UI, stable canonical Relation editor integration, and consistent layouts/query controls.

### Milestone B — Multi-View Database UX
Multiple independent Views per Database, top tabs, duplicate-current/blank creation, rename/reorder/delete, independent config and overflow handling.

Core create/rename/reorder/duplicate/delete behavior is now integrated in the shared tabs; overflow and wider page-level integration remain.

### Milestone C — Object Knowledge System
User-facing reusable Tag/Weblink/Image flows, Value -> Object affordances, richer relations/backlinks, shared contextual Object detail/opening, stronger Daily Note integration.

Typed View-level Object opening-mode storage/resolution is now available; navigation/presentation still needs wiring.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects, embedded Database/Views, and higher-level time-based note compositions.

## Next repository-wide actions

1. Patch `GenericDatabasePage` from latest `main` in a patch-capable implementation environment.
2. Wire `GenericDatabaseCollectionPageLoader` into the real page so Database membership resolves first and existing View projection remains the second stage.
3. Replace legacy Object creation assumptions with `GenericDatabaseObjectCreateService`; connect Board `onCreateInGroup` end-to-end.
4. Migrate real Relation picker/editor UI onto `ObjectRelationEditorService`; surface missing-target/cardinality diagnostics without silent repair.
5. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
6. Add focused page/widget regression coverage for collection-aware reload/create/Relation edit paths.
7. Add View overflow handling and expose `DatabaseViewOpenModeService` in View settings/open behavior.
8. Expose reversible URL Value -> reusable Weblink promotion through a narrow Object-owned affordance while preserving the source URL by default.
9. Complete contextual side-peek / center-peek / full-page Object opening after Database/View navigation state is stable.
10. Continue Milestone C/D after the Database/View core is coherent; manual include/exclude remains deferred until dynamic collection + multi-View behavior is stable.

## Validation status

- PR #82 Flutter CI #474: success.
- PR #86 Flutter CI #477: success.
- PR #87 Flutter CI #480: success.
- PR #88 Flutter CI #481: success.
- PR #89 Flutter CI #488: Drift generation, `flutter analyze`, full tests — success before merge.
- PR #90 Flutter CI #489: Drift generation, `flutter analyze`, full tests — success before merge.

## Known risks / sequencing constraints

- `GenericDatabasePage` is the main integration hotspot. Avoid parallel broad edits from Object and Relation lanes.
- Legacy page logic still assumes in places that Database id and ObjectType id are identical; remove that assumption incrementally using the merged collection loader/creation adapters.
- User-facing Relation mutation must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state.
- Board Relation-group creation must continue through the safe mutation facade.
- Database collection definitions must remain distinct from View config and must not duplicate Object ownership.
- ObjectType and Database are conceptually distinct even though legacy UI/storage still overlaps them in places; migrate incrementally rather than destructively.
- Rich Body documents must never be flattened by the initial paragraph-safe editor.
