# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

The product direction remains: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

Issue #56 now contains the current execution roadmap and delivery milestones A–D. Treat it as the product/design contract.

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

## Sustained-run policy

Implementation runs should continue through multiple safe slices. One PR/commit/test or merely pending CI is not a stopping condition when independent safe work remains. Keep branches focused and avoid concurrent broad edits to the same core file.

## Current implementation position

The repository is no longer primarily in foundational Object/Relation work. Most core primitives are present. The active phase is **Database/View integration and user-facing UX**.

### Integrated Object / database foundations on `main`

- PR #61: Value / Object Relation / Computed Property semantics.
- PR #64: Value-to-Object planning, versioned Body blocks, ObjectType defaults contract, shared Object detail contracts.
- PR #65: Body/default persistence, Weblink Object service, Daily Note open-or-create, shared detail loading, paragraph-safe Body adapter.
- PR #71: shared Object detail editing/session, Daily Note detail bridge, persisted defaults resolution, reusable Image Object facade.
- PR #68: Object inspector uses shared detail content, Formula/Rollup, persisted Body editing, and today's Daily Note navigation.
- PR #76: shared Object detail state composes with canonical Relation neighborhood data.
- PR #77: safe Value -> Object execution and reusable URL -> Weblink promotion; Relation writes delegate to `RelationMutationService`.
- PR #78: `ObjectInspectorPage` renders outgoing Relations and Backlinks from canonical Relation neighborhood data.
- PR #79: grouped Board Object creation planner/service merged, including Relation-safe grouped presets through `RelationMutationService`.

### Integrated Relation foundations on `main`

- PR #62: broken bidirectional inverse metadata fails closed.
- PR #66: canonical Relation source/target validation, mutation/read/index APIs, lifecycle hardening, Relation-safe Object deletion, Tag hierarchy cleanup.
- PR #69: read-only Relation integrity auditing.
- PR #73: canonical `RelationNeighborhood` outgoing + backlink payload.
- PR #74: fail-closed deterministic Relation index reconciliation for index-only drift.
- PR #75: canonical same-workspace Relation picker candidates.
- PR #80: canonical Relation selection context including missing-target diagnostics and cardinality drift without mutation.
- PR #81: `CoreObjectBridge` Image/Tag writes and orphan mirror cleanup use the safe Relation lifecycle.

### Active core slice

PR #82 (`feature/database-collection-semantics`) is open and mergeable. Its latest work provides the Phase-1 Database collection foundation:

- `DatabaseCollectionDefinition`
- `Database = target ObjectType + collectionFilter`
- persistence separate from View configuration
- legacy self-type fallback for existing databases
- `DatabaseCollectionResolver`
- Database-collection-then-View projection composition
- `DatabaseCollectionConfigService`
- same-workspace target/config validation
- additive/non-destructive storage

Do not merge until the latest-head CI is green or an explicit decision overrides that requirement.

### Explicitly not active

PR #83 was created accidentally after a stop request. It is closed and unmerged. Do not treat its branch as an active implementation path; reconsider any useful idea later against current `main` and Issue #56.

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
Complete Database collection semantics in the real page, Board create-in-group UI, stable Relation editor/picker integration, and consistent layouts/query controls. This is the point where day-to-day use as a generic DB should begin.

### Milestone B — Multi-View Database UX
Multiple independent Views per Database, top tabs, duplicate-current/blank creation, rename/reorder/delete, independent configuration and overflow handling.

### Milestone C — Object Knowledge System
User-facing reusable Tag/Weblink/Image flows, Value -> Object affordances, richer relations/backlinks, shared contextual Object detail/opening, stronger Daily Note integration.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects, embedded Database/Views, and higher-level time-based note compositions.

## Next repository-wide actions

1. Validate and land PR #82 on current `main`.
2. Integrate Database-first collection resolution into `GenericDatabasePage`, then apply View projection as a separate second layer.
3. Connect merged `ObjectBoardCreateService` to the real `ObjectBoardView.onCreateInGroup` UI and add regression coverage.
4. Migrate real Relation picker/editor reads to canonical selection/candidate APIs and writes to `RelationMutationService`; surface missing-target/cardinality diagnostics without silent repair.
5. Expose reversible URL Value -> reusable Weblink promotion through a narrow Object-owned UI affordance while preserving the source URL by default.
6. Implement multiple Views per Database with top-tab navigation.
7. Implement View duplicate/blank creation, rename, reorder, and delete with independent mutable configs.
8. Complete shared side-peek / center-peek / full-page Object opening behavior.
9. Begin practical use after Milestone A/B rather than waiting for advanced block/document features.
10. Continue Milestone C/D only after the Database/View core is coherent.
11. Add manual include/exclude collection overrides only after dynamic collection + multi-View behavior is stable.

## Validation status

- Merged Object slices #76/#77/#78 were CI-green before merge.
- Merged Relation slices #66/#69/#73/#74/#75/#80/#81 were validated through Flutter CI before merge.
- PR #79 is merged; the prior handoff entry that called it active was stale and has been corrected here.
- PR #82 remains open; always inspect its latest head and latest Flutter CI before integration.

## Known risks / sequencing constraints

- `GenericDatabasePage` is now the main integration hotspot. Avoid parallel broad edits from Object and Relation lanes.
- User-facing Relation mutation must not regress to low-level direct Relation writes; use `RelationMutationService`.
- Picker opening/loading must not silently rewrite legacy/corrupt Relation state.
- Board Relation-group creation must continue using the safe Relation mutation facade.
- Database collection definitions must remain distinct from View config and must not duplicate Object ownership.
- ObjectType and Database are conceptually distinct even though legacy UI/storage still overlaps them in places; migrate incrementally rather than destructively.
- Rich Body documents must never be flattened by the initial paragraph-safe editor.
