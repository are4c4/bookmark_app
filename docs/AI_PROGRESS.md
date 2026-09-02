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
- PR #76 merged: shared Object detail state composes with canonical Relation `neighborhood()` data.
- PR #77 merged: safe Value -> Object execution and reusable URL -> Weblink promotion; Relation writes delegate to `RelationMutationService`.
- PR #78 merged: `ObjectInspectorPage` renders outgoing Relations and Backlinks from canonical Relation neighborhood data.
- PR #79 remains active: grouped Board Object creation is replayed on current foundations; its Relation-group initialization routes through `RelationMutationService`, and its next integration surface is `GenericDatabasePage`.

### Relation foundation

- PR #62 merged: broken bidirectional inverse metadata fails closed.
- PR #66 merged: canonical Relation source/target validation, mutation/read/index APIs, lifecycle hardening, Relation-safe Object deletion, Tag hierarchy cleanup.
- PR #69 merged: read-only Relation integrity auditing.
- PR #73 merged: canonical `RelationNeighborhood` outgoing + backlink payload.
- PR #74 merged: fail-closed deterministic Relation index reconciliation for index-only drift.
- PR #75 merged: `RelationTargetService` canonical same-workspace Relation-picker candidates.
- PR #80 merged as `614d654e6bb08011d9cb4ca242b50174ce44e5e4`: `RelationTargetService.selectionFor()` now returns canonical source/target selection state, missing target diagnostics, and single-cardinality drift without mutating data.
- PR #81 merged as `0390d12162cb2a2dd5c063e8e4cbca95f036a248`: `CoreObjectBridge` Images/Tags writes and orphan mirror cleanup now use the safe Relation lifecycle, including detaching incoming references before mirrored Object deletion.

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

1. Validate/land Object PR #79 and continue its `GenericDatabasePage` Board integration without bypassing the Relation lifecycle.
2. In the same Object-owned `GenericDatabasePage` sequencing window, migrate real Relation editing/pickers to:
   - `RelationTargetService.selectionFor()` for canonical current selection/candidates/diagnostics;
   - `RelationMutationService.setRelation()` for writes.
3. When a picker opens legacy/corrupt state, surface missing target ids/cardinality drift rather than silently rewriting the stored Relation merely by opening/closing the UI.
4. Expose reversible URL Value -> reusable Weblink promotion through a narrow Object-owned UI affordance; preserve source Value by default.
5. Continue Object-centric Database/View integration and Board workflows under Issue #56 without duplicating Object or Relation records.
6. Keep Relation lane focused on concrete regressions discovered during integration rather than competing edits to Object-owned UI.

## Validation

- PR #76 Flutter CI: success before merge.
- PR #77 Flutter CI: success after analyzer correction; Drift generation, analyze, and tests passed before merge.
- PR #78 Flutter CI: success before merge.
- PR #79 remains an active Object-lane integration PR.
- Relation PR #80 corrected latest head `56f634d666c2d4e15fc5917f0559ef2fb02225cd`: dependency install, Drift generation, `flutter analyze`, full tests — success before merge. Its earlier run failed only one new test because candidate ordering was incorrectly asserted; implementation/analyzer were green.
- Relation PR #81 head `c99ee94ea26bb2588e27321398ebe635870e2f8d`: dependency install, Drift generation, `flutter analyze`, full tests — success before merge.
- Earlier merged Relation slices #66/#69/#73/#74/#75 each passed Flutter CI before merge.

## Known risks

- `GenericDatabasePage`, Object detail presentation, Value promotion UI and Board integration are Object-owned integration surfaces even when they consume Relation APIs.
- Low-level generic ObjectStore operations remain available, but user-facing Relation mutations should use `RelationMutationService`.
- `CoreObjectBridge` has completed its deliberately sequenced Relation lifecycle migration; future feature ownership returns to the Object lane.
- `GenericDatabasePage` still contains a low-level Relation write until the Object lane completes the picker/editor migration; active PR #79 plans to touch that same file, so Relation lane should not create a competing edit.
- Board Relation-group creation must preserve the same safe-mutation rule.
- Do not auto-repair ambiguous persisted Relation values; only deterministic index-only reconciliation is currently safe.
- Rich Body documents must not be flattened by the initial paragraph-safe editor.
