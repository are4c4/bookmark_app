# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing database workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - Object-centric Database/View integration
   - reusable Object types
   - Object detail content and Body/block model
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

## Latest relevant state

### Object foundation / integration

- PR #61 merged: explicit Value / Object Relation / Computed Property semantics.
- PR #64 merged: Value-to-Object planning, versioned Body blocks, ObjectType defaults contract, shared Object detail contracts.
- PR #65 merged: Body/default persistence, Weblink Object service, Daily Note open-or-create, shared detail loading, paragraph-safe Body adapter.
- PR #71 merged: shared Object detail editing/session, Daily Note detail bridge, persisted defaults resolution, reusable Image Object facade.
- PR #68 merged: Object inspector uses shared detail content, Formula/Rollup, persisted Body editing, and general Object navigation for today's Daily Note.
- PR #76 merged: shared Object detail state composes with canonical Relation neighborhood data.
- PR #77 merged: safe Value -> Object execution and reusable URL -> Weblink promotion; Relation writes use `RelationMutationService`.
- PR #78 merged: Object inspector renders outgoing Relations and Backlinks from canonical Relation neighborhood data.
- PR #79 merged as `6b991708f294e83b236d396a84d3841e4e43bcd4`: grouped Board Object creation is integrated. Relation presets use `RelationMutationService`; failed preset writes roll back the new Object. Flutter CI #458 passed before merge.
- PR #82 is active on `feature/database-collection-semantics`: Phase-1 `Database = target ObjectType + collectionFilter` persistence, membership resolution, Database-before-View projection, delete integrity, and UI-facing configuration facade.

### Relation foundation

- PR #62 merged: broken bidirectional inverse metadata fails closed.
- PR #66 merged: canonical Relation source/target validation, mutation/read/index APIs, lifecycle hardening, Relation-safe Object deletion, Tag hierarchy cleanup.
- PR #69 merged: read-only Relation integrity auditing.
- PR #73 merged: canonical `RelationNeighborhood` outgoing + backlink payload.
- PR #74 merged: fail-closed deterministic Relation index reconciliation for index-only drift.
- PR #75 merged: `RelationTargetService` canonical same-workspace Relation-picker candidates.
- Newer Relation integration has also advanced main with canonical selection/lifecycle consumers; Object lane continues to consume stable Relation APIs rather than duplicating their rules.

### Database collection Phase 1

- Database collection definition is explicitly separate from View configuration.
- Existing databases remain backward compatible as self ObjectType + empty collection filter until configured.
- Explicit collection targets are same-workspace ObjectTypes and filter Properties must belong to the target type.
- `DatabaseCollectionResolver` produces the broad membership set; `DatabaseCollectionViewProjector` then applies View search/filter/sort/group independently.
- Additive persistence introduces no Object/Bookmark rewrite or destructive migration.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- Database = which Objects; View = how to see them.
- Phase-1 Database membership = target ObjectType + `collectionFilter`.
- Database `collectionFilter` and View filters are separate persisted/query layers.
- ObjectType = schema + defaults.
- Effective defaults resolve as `View override > Database override > ObjectType default > app default`.
- Object content = structured Properties + free Body designed for blocks.
- Property semantics distinguish Value, Object Relation, and computed properties.
- Tags are Objects; Select/MultiSelect remain for local option sets.
- Date is a Value; Daily Note is an Object keyed by a unique date.
- Object detail presentation should support side peek, center peek, and full page with shared content.

## Next repository-wide actions

1. Validate and land Object PR #82.
2. Wire Database collection membership into the real `GenericDatabasePage` before View projection.
3. Add a narrow collection settings UI for target ObjectType + collection filters while keeping View filters in the existing View toolbar.
4. Wire merged Board grouped creation service to the Board-column `新規Object` callback in `GenericDatabasePage`.
5. Use `RelationTargetService` + `RelationMutationService` for Relation editing/pickers and `RelationReadService.neighborhood()` for Object graph context.
6. Continue Object-centric Database/View integration under Issue #56 without duplicating Object or Relation records.

## Validation

- PR #79 Flutter CI #458: Drift generation, analyze, and full tests passed before merge.
- PR #82 CI #466: Drift generation and analyze passed; 266 tests passed and two new tests failed only because their expected Object order contradicted the existing `ObjectStore` ordering. Those test expectations were corrected without changing membership behavior.
- Latest PR #82 CI is running on the newer head that also includes `DatabaseCollectionConfigService` coverage.

## Known risks

- `GenericDatabasePage`, Object detail presentation, Value promotion UI, and collection configuration are Object-owned integration surfaces even when they consume Relation APIs.
- User-facing Relation mutations must use `RelationMutationService`; Relation pickers should use canonical target/selection APIs.
- Database collection integration must never collapse collection filters into View filters or duplicate Objects merely because a Database targets another ObjectType.
- Do not auto-repair ambiguous persisted Relation values; only deterministic index-only reconciliation is currently safe.
- Rich Body documents must not be flattened by the initial paragraph-safe editor.
