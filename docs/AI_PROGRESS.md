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
- PR #82 merged as `689c84de46cee1292f7f126eb3d5719658f8d8e8`: Phase-1 `Database = target ObjectType + collectionFilter`, separate persistence, collection resolver/config service, and Database-first/View-second projection composition. Latest-head Flutter CI #474 passed.
- PR #85 merged: Database collection settings dialog for target ObjectType and collection-filter editing, independent from View configuration.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: collection-aware page loader that preserves Database identity/View scope while sourcing filtered Objects/records/Properties from the target ObjectType. Flutter CI #477 passed.

### Integrated Relation foundations on `main`

- PR #62/#66/#69/#73/#74/#75/#80/#81: canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, canonical picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.

### Active Object integration PRs

- PR #87 `feature/object-page-integration-services`
  - collection-aware normal/Board Object creation;
  - canonical Object-owned Relation editor adapter consuming `RelationTargetService.selectionFor()` + `RelationMutationService`;
  - focused tests for cross-ObjectType collection creation, grouped presets, canonical Relation selection and invalid-target rejection;
  - Flutter CI #480 running on head `43a75a6a2b03bdf8424dc9814a82d847ceecf688` at the latest handoff.

- PR #88 `feature/object-view-creation-service`
  - adopted dual-path View creation service: duplicate-current as primary, blank View as secondary;
  - duplicate receives a new identity and remains independently mutable;
  - Flutter CI #481 running on head `6f4ad751490849d8e612844a17e59366c7b60a0b` at the latest handoff.

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

### Milestone C — Object Knowledge System
User-facing reusable Tag/Weblink/Image flows, Value -> Object affordances, richer relations/backlinks, shared contextual Object detail/opening, stronger Daily Note integration.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects, embedded Database/Views, and higher-level time-based note compositions.

## Next repository-wide actions

1. Validate/land PR #87 and PR #88 when latest-head Flutter CI is green; fix branch-caused failures first.
2. Refresh `GenericDatabasePage` from latest `main` after those merges.
3. Wire `GenericDatabaseCollectionPageLoader` into the real page so Database membership resolves first and existing View projection remains the second stage.
4. Replace legacy Object creation assumptions with the collection-aware creation service; connect Board `onCreateInGroup` end-to-end.
5. Migrate real Relation picker/editor UI onto the canonical Object-owned adapter; surface missing-target/cardinality diagnostics without silent repair.
6. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
7. Add focused page/widget regression coverage for collection-aware reload/create/Relation edit paths.
8. Wire the adopted duplicate-current and blank View creation paths into top-tab multi-View UX, then rename/reorder/delete/overflow.
9. Expose reversible URL Value -> reusable Weblink promotion through a narrow Object-owned affordance while preserving the source URL by default.
10. Complete contextual side-peek / center-peek / full-page Object opening after Database/View navigation state is stable.
11. Continue Milestone C/D after the Database/View core is coherent; manual include/exclude remains deferred until dynamic collection + multi-View behavior is stable.

## Validation status

- PR #82 latest-head Flutter CI #474: success before merge.
- PR #86 Flutter CI #477: success before merge.
- PR #87 Flutter CI #480: in progress at latest handoff.
- PR #88 Flutter CI #481: in progress at latest handoff.

## Known risks / sequencing constraints

- `GenericDatabasePage` is the main integration hotspot. Avoid parallel broad edits from Object and Relation lanes.
- Legacy page logic still assumes in places that Database id and ObjectType id are identical; remove that assumption incrementally using the new collection loader/creation adapters.
- User-facing Relation mutation must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state.
- Board Relation-group creation must continue through the safe mutation facade.
- Database collection definitions must remain distinct from View config and must not duplicate Object ownership.
- ObjectType and Database are conceptually distinct even though legacy UI/storage still overlaps them in places; migrate incrementally rather than destructively.
- Rich Body documents must never be flattened by the initial paragraph-safe editor.
