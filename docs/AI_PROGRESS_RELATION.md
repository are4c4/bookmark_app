# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, relation write validation, rename/delete propagation, target constraints, stale/inconsistent metadata handling, Tag hierarchy through Relations, and reusable Relation APIs consumed by Object-owned hosts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state
- Relation foundation PRs #62/#66/#69/#73/#74/#75/#80/#81 are merged.
- PR #109 editor-boundary regression coverage is merged as `d51b5023ede27bcf0c66670620e86643a1b07038`.
- Object PR #111 completed the real `GenericDatabasePage` Relation picker/editor migration through `GenericDatabasePageServices.relationEditor`.
- PR #114 `Cover Relation lifecycle in real database host` is merged as `a152c4984331789af8450bfe10ed62a4bea0cce1`.
- `lib/views` no longer contains a user-facing direct `ObjectStore.setRelation()` call; real page writes route through the canonical Relation editor/mutation facade.
- Object PRs #112/#113/#115 are merged Object inspector/Body integration and do not change Relation lifecycle.
- Object PR #116 is active Daily Note/Object inspector work; its scope explicitly contains no Relation lifecycle changes.
- No active Relation implementation PR remains.

## Stable Relation APIs on main

### Mutation / lifecycle
- `RelationMutationService`
  - canonical persisted Property resolution;
  - safe unidirectional and bidirectional writes;
  - pair-aware rename/delete;
  - Relation-safe Object deletion that detaches surviving references first;
  - fail-closed behavior for inconsistent bidirectional metadata.
- `BidirectionalRelationStore`
  - reciprocal pair validation;
  - canonical pair writes;
  - transactional pair rename/delete.

### Read / backlinks
- `RelationReadService`
  - resolved outgoing Relations;
  - resolved backlinks;
  - `RelationNeighborhood` for shared Object graph context.

### Picker / editor
- `RelationTargetService.selectionFor()` returns canonical source Object, valid candidates, selected ids/Objects, missing target ids, and single-cardinality diagnostics without mutation.
- `ObjectRelationEditorService`
  - load delegates to canonical selection;
  - explicit save accepts only canonical candidates and enforces cardinality;
  - writes delegate to `RelationMutationService`.
- `GenericDatabasePageServices.relationEditor` composes the canonical path used by the real `GenericDatabasePage`.
- Real picker behavior on main:
  - opening is read-only;
  - missing-target/cardinality diagnostics are shown;
  - save occurs only after explicit user action;
  - stale target deletion after load fails closed and surfaces an error;
  - bidirectional saves synchronize the inverse side.

### Persistence / integrity
- `RelationIndexService` rebuilds normalized edges from persisted Relation values.
- `RelationIntegrityService` audits missing/cross-workspace targets, cardinality, index drift, bidirectional metadata and inverse mismatches without mutating user values.
- `RelationIndexReconcileService` repairs only deterministic index-only drift and refuses ambiguous repair.

### Tag / legacy mirror lifecycle
- Legacy Tag -> Tag Object synchronization uses general Relation lifecycle APIs.
- Removing orphan Tag Objects cleans incoming Parent Relations.
- `CoreObjectBridge` Images/Tags writes use `RelationMutationService`.
- Orphan mirrored Image/Bookmark deletion uses Relation-safe Object deletion.

## Checkpoints completed in the latest audit run
1. Re-read `AGENTS.md`, Issue #56, repository handoff, Relation handoff, and latest PR state.
2. Confirmed #114 remains the latest Relation implementation checkpoint and is merged after CI-green real-host lifecycle coverage.
3. Reviewed recent Object integration sequence: #112/#113/#115 are merged; #116 is active Daily Note/Object inspector integration and explicitly has no Relation lifecycle changes.
4. Re-audited `setRelation(` call sites. User-facing host writes remain absent from `lib/views`; remaining low-level calls are canonical service internals, bridge/services that already use `RelationMutationService`, or tests/corruption fixtures.
5. Re-audited `relationEditor` usage and confirmed the real `GenericDatabasePage` continues to load/save through `GenericDatabasePageServices.relationEditor` rather than a new parallel lifecycle path.
6. No new editable Relation surface was introduced in Object inspector or Daily Note work; current Object detail Relation consumption remains presentation/navigation only.
7. No concrete failing Relation correctness case, API gap, backlink/index regression, or lifecycle defect was found that can be implemented independently without inventing speculative abstraction or ambiguous repair policy.

## Validation
- PR #114 corrected head `e3b357c5427e43d4ba248d2391ffe73e48253812`: Drift generation — success; `flutter analyze` — success; full test suite — success (Flutter CI #620).
- PR #109 head `576346d836c2ad07c3f2a590640751dd8b107741`: Drift generation, analyze, full tests — success (Flutter CI #597).
- Previous Relation PRs #66/#69/#73/#74/#75/#80/#81 were CI-green before merge.
- This latest run made no code changes because the audit found no concrete Relation defect; therefore no new CI run was warranted.

## Exact next actions
1. Treat the real `GenericDatabasePage` Relation editor acceptance path as integrated and covered; do not create another parallel picker/editor abstraction.
2. Resume Relation implementation when real-host usage or a new Object-owned editable Relation surface exposes a concrete lifecycle/read/index/backlink regression; begin with a focused failing test.
3. Keep integrity audit and repair separate. Do not auto-repair missing targets, cardinality conflicts, broken bidirectional values, or other ambiguous user data without explicit product/data policy.
4. Continue Tag hierarchy and legacy mirror changes only through the general Relation APIs.
5. If Object detail gains Relation editing, reuse `RelationTargetService` / `ObjectRelationEditorService` with non-mutating load and explicit save, then add end-to-end host regression coverage before considering the path complete.

## Cross-lane boundary
- `GenericDatabasePage`, Object detail/navigation, Daily Note host integration, Body UI and View/Database navigation remain Object-owned host surfaces.
- The real Database page consumes the stable Relation boundary correctly; Relation lane should not compete with ongoing Object host work unless fixing a concrete Relation regression.
- `lib/data/object_store.dart` is shared infrastructure; future Relation edits there must stay narrow and refresh latest main first.
- Active Object PR #116 does not require a Relation dependency at this time.

## Known risks / blockers
- Low-level generic ObjectStore operations remain intentionally available for persistence internals, corruption simulation tests, and rollback paths; normal user-facing Relation mutations must continue using the canonical facade.
- Missing-target/cardinality/bidirectional-value automatic repair remains intentionally explicit-only because choosing a repair policy can discard user intent.
- Object detail currently consumes canonical Relation presentation/read data; any future editable Relation UI there must preserve the same non-mutating-load / explicit-save contract.

## Stop reason
The lane currently satisfies the AGENTS.md stopping criterion "no remaining actionable work in the Issue" for independent Relation work. The real Database Relation lifecycle is integrated and covered, low-level user-facing writes are gone, and the latest Object host work introduces no new Relation write path. Further work now depends on a concrete regression or a new editable Relation host surface; inventing additional abstractions or automatic repair policy would violate the integration-first and explicit-repair design rules.
