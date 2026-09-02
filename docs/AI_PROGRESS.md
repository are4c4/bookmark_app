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
- PR #68 merged into `main` as `c112f165ffbda7b032fd51426579cfdc4325de0e`: the existing Object inspector now uses shared detail content, renders Formula/Rollup, exposes persisted Body editing safely, and provides a general Object-surface entry for today's Daily Note.
- PR #76 is open on current Object base: shared Object detail + canonical `RelationNeighborhood` composition. It supersedes stale #72.
- PR #77 is open on current Object base: safe Value -> Object execution plus reusable URL -> Weblink promotion. It supersedes stale #70.

### Relation foundation

- PR #62 merged: broken bidirectional inverse metadata fails closed.
- PR #66 merged: canonical Relation source/target validation, mutation/read/index APIs, lifecycle hardening, Relation-safe Object deletion, Tag hierarchy cleanup.
- PR #69 merged: read-only Relation integrity auditing.
- PR #73 merged: canonical `RelationNeighborhood` outgoing + backlink payload.
- PR #74 merged: fail-closed deterministic Relation index reconciliation for index-only drift.
- PR #75 merged: `RelationTargetService` canonical same-workspace Relation-picker candidates.

### Existing generic foundations

Object query/filter/sort, grouping, Board view and drag/drop persistence, Formula/Rollup, bidirectional Relations, ObjectType templates/management, Body/default persistence, Daily Notes, Weblink/Image reusable Object facades, and stable Relation graph/lifecycle services are present.

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

1. Validate and land Object PR #76, then use its shared Relation context in Object detail/Daily Note presentation.
2. Validate and land Object PR #77, then expose reversible Value -> Object promotion through a narrow Object-owned UI/service path.
3. Use `RelationTargetService` + `RelationMutationService` for Relation editing/pickers and `RelationReadService.neighborhood()` for Object graph context.
4. Continue Object-centric Database/View integration and Board workflows under Issue #56 without duplicating Object or Relation records.
5. Keep Relation lane focused on regressions found during integration rather than competing edits to Object-owned UI.

## Validation

- PR #68 head Flutter CI #423 succeeded before merge.
- PR #76 CI #434 is in progress at this handoff.
- PR #77 CI #435 is in progress at this handoff.
- Latest merged Relation slices #66/#69/#73/#74/#75 each passed Flutter CI before merge.

## Known risks

- PR #76 and #77 were both created from the same Object base; re-check mergeability after either lands.
- `GenericDatabasePage`, Object detail presentation, Value promotion UI and `core_object_bridge.dart` are Object-owned integration surfaces even when they consume Relation APIs.
- Low-level generic ObjectStore operations remain available, but user-facing Relation mutations should use `RelationMutationService`.
- Do not auto-repair ambiguous persisted Relation values; only deterministic index-only reconciliation is currently safe.
- Rich Body documents must not be flattened by the initial paragraph-safe editor.
