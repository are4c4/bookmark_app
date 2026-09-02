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
- PR #68 merged: existing Object inspector uses shared detail content, Formula/Rollup, persisted Body editing, and general Object navigation for today's Daily Note.
- PR #76 merged as `dac4a64f22d6ab63279ed3075664847f213cf992`: shared Object detail state can be composed with canonical Relation `neighborhood()` data.
- PR #77 merged as `d952ec409fdf69b45219ae00d3c38d3c74b59619`: safe Value -> Object execution and reusable URL -> Weblink promotion are integrated; user-facing Relation writes delegate to `RelationMutationService`.
- PR #78 merged as `521063771df658058dd625a5601a22f6ca77332e`: `ObjectInspectorPage` now renders outgoing Relations and Backlinks from the canonical Relation neighborhood instead of ad-hoc graph queries.
- PR #79 is active: grouped Board Object creation has been replayed on current foundations. Its known stale test-constructor mismatch was fixed, and Relation-group initialization now routes through `RelationMutationService`.

### Relation foundation

- PR #62 merged: broken bidirectional inverse metadata fails closed.
- PR #66 merged: canonical Relation source/target validation, mutation/read/index APIs, lifecycle hardening, Relation-safe Object deletion, Tag hierarchy cleanup.
- PR #69 merged: read-only Relation integrity auditing.
- PR #73 merged: canonical `RelationNeighborhood` outgoing + backlink payload.
- PR #74 merged: fail-closed deterministic Relation index reconciliation for index-only drift.
- PR #75 merged: `RelationTargetService` canonical same-workspace Relation-picker candidates.

### Existing generic foundations

Object query/filter/sort, grouping, Board view and drag/drop persistence, Formula/Rollup, bidirectional Relations, ObjectType templates/management, Body/default persistence, Daily Notes, Weblink/Image reusable Object facades, safe Value promotion, and stable Relation graph/lifecycle services are present.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- Database = which Objects; View = how to see them.
- ObjectType = schema + defaults.
- Effective defaults resolve as `View override > Database override > ObjectType default > app default`.
- Object content = structured Properties + free Body designed for blocks.
- Property semantics distinguish Value, Object Relation, and computed properties.
- Tags are Objects; Select/MultiSelect remain for local option sets.
- Date is a Value; Daily Note is an Object keyed by a unique date.
- Object detail presentation should support side peek, center peek, and full page with shared content.

## Next repository-wide actions

1. Validate and land Object PR #79, then wire grouped Board creation to the existing Board-column `新規Object` callback in `GenericDatabasePage`.
2. Expose reversible URL Value -> reusable Weblink promotion through a narrow Object-owned UI affordance; preserve the source Value by default.
3. Use `RelationTargetService` + `RelationMutationService` for Relation editing/pickers and `RelationReadService.neighborhood()` for Object graph context.
4. Continue Object-centric Database/View integration and Board workflows under Issue #56 without duplicating Object or Relation records.
5. Keep Relation lane focused on regressions found during integration rather than competing edits to Object-owned UI.

## Validation

- PR #76 Flutter CI #434: success before merge.
- PR #77 Flutter CI #439: success after analyzer correction; Drift generation, analyze, and tests passed before merge.
- PR #78 Flutter CI #440: success before merge.
- PR #79 CI #441 identified one stale test-helper constructor error before tests. The exact job log was inspected and corrected; newer CI is running on the corrected Relation-safe head.
- Latest merged Relation slices #66/#69/#73/#74/#75 each passed Flutter CI before merge.

## Known risks

- `GenericDatabasePage`, Object detail presentation, Value promotion UI and `core_object_bridge.dart` are Object-owned integration surfaces even when they consume Relation APIs.
- Low-level generic ObjectStore operations remain available, but user-facing Relation mutations should use `RelationMutationService`.
- Board Relation-group creation must preserve the same rule; do not bypass Relation lifecycle when wiring the UI.
- Do not auto-repair ambiguous persisted Relation values; only deterministic index-only reconciliation is currently safe.
- Rich Body documents must not be flattened by the initial paragraph-safe editor.
