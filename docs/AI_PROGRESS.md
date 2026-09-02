# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing database workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

The implementation is split into two concurrent-capable lanes matching the current implementation chats:

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
   - Relation APIs and Tag hierarchy expressed through Relations

`docs/AI_PROGRESS_OBJECT_RELATION.md` is retained only as legacy combined context. New runs should write to the dedicated Object or Relation handoff file.

Each implementation chat/run must pick one primary lane and update its matching progress file unless repository-wide integration state changes.

## Sustained-run policy

Implementation runs should not stop after the first small PR/commit/checkpoint when Issue #56 still contains safe work for that lane. After each coherent slice, commit/push, record the checkpoint, then continue with the next non-conflicting slice.

Pending/queued CI by itself is not a blocker. While CI is pending, continue with work that does not depend on that CI result. Stop only for a genuine design/risk/cross-lane blocker, external infrastructure with no independent safe work remaining, or an actual runtime/tool/session limit.

## Latest relevant state

### Object foundation

- PR #61 is merged; Value / Object Relation / Computed Property semantics are on `main`.
- PR #64 is merged; Object promotion planning, versioned Body blocks, ObjectType defaults contract, and shared Object detail contracts are on `main`.
- PR #65 is merged; Object Body/defaults persistence, Weblink Object service, Daily Note open-or-create, detail loading, and safe plain-text Body adapter are on `main`.
- Active Object work is consuming the stable Relation APIs rather than duplicating lifecycle logic:
  - PR #70 uses `RelationMutationService` for Value -> Object promotion execution.
  - PR #72 uses `RelationReadService` for shared Object detail Relation context.

### Relation foundation

- PR #62 is merged; bidirectional pair validation rejects broken inverse metadata.
- PR #66 is merged; source/target validation, stable mutation/read/index APIs, bidirectional lifecycle hardening, Relation-safe Object deletion, and Tag hierarchy cleanup are on `main`.
- PR #69 is merged; read-only Relation integrity auditing is on `main`.
- PR #73 is merged; `RelationNeighborhood` provides one resolved outgoing + backlink payload for Object-detail consumers.
- PR #74 is merged; normalized Relation index drift can be reconciled only when audit proves the inconsistency is index-only.
- PR #75 is merged; `RelationTargetService` provides canonical same-workspace target candidates for Relation pickers.
- Latest Relation code integration commit before handoff updates: `b6511bf36e37e0bea84ac99da745ee40f85e1cb1`.

### Existing generic foundations

Object query/filter/sort, grouping, Board view and drag/drop persistence, Formula/Rollup, bidirectional Relations, ObjectType templates, ObjectType management, Body/default persistence, Daily Notes, reusable Weblink, and stable Relation graph/lifecycle services are present. Issue #56 remains the shared product/design contract for turning these foundations into one coherent user-facing workflow.

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

## Integration policy

- Keep `main` releasable.
- Use focused lane-specific branches/PRs/checkpoints.
- Avoid both lanes concurrently owning broad refactors of the same core file.
- If a change crosses lanes, document the dependency and sequence overlapping work where practical.
- Rebase/refresh from latest `main` before merging overlapping foundation changes.
- Preserve existing bookmark data and behavior; no destructive migrations without explicit approval.

## Next repository-wide actions

1. Object lane should continue user-facing integration using the now-stable Relation boundaries:
   - `RelationTargetService` + `RelationMutationService` for Relation editing/pickers;
   - `RelationReadService` / `RelationNeighborhood` for Object detail and Daily Note graph context;
   - sequence any `core_object_bridge.dart` migration from the Object lane because it is an Object-owned synchronization surface.
2. Continue Object detail, Value-to-Object promotion, Daily Note, Database/View and Board integration under `docs/AI_PROGRESS_OBJECT.md`.
3. Relation lane should remain available for focused regressions discovered during Object integration, but should not broaden into competing edits of Object-owned UI.
4. Do not implement ambiguous Relation-value auto-repair without an explicit data/product policy. Deterministic index-only reconciliation is already supported.

## Validation

The latest merged Relation slices were individually validated through GitHub Actions before merge:

- PR #66: Drift generation, `flutter analyze`, full tests — success.
- PR #69: Drift generation, `flutter analyze`, full tests — success.
- PR #73: Drift generation, `flutter analyze`, full tests — success.
- PR #74: Drift generation, `flutter analyze`, full tests — success.
- PR #75: Drift generation, `flutter analyze`, full tests — success.

Object-lane validation details remain in `docs/AI_PROGRESS_OBJECT.md` and the active Object PRs.

## Known risks

- Parallel work is useful only when file ownership is reasonably separate; replay narrow lane changes on latest `main` rather than force-merging stale shared files.
- `GenericDatabasePage`, Object detail presentation, Value promotion UI and `core_object_bridge.dart` are Object-owned integration surfaces even where they use Relation APIs.
- Low-level `ObjectStore` delete/property APIs remain available for generic infrastructure; Relation-aware user-facing flows should consume `RelationMutationService`.
- Integrity diagnostics and deterministic index reconstruction are safe; repairing ambiguous persisted Relation values could discard user intent and requires an explicit decision.
