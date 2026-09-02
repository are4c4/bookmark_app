# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, relation write validation, rename/delete propagation, target constraints, stale/inconsistent metadata handling, Tag hierarchy through Relations, and reusable Relation APIs consumed by Object-owned hosts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state
- Relation foundation PRs #62/#66/#69/#73/#74/#75/#80/#81 are merged.
- PR #109 editor-boundary regression coverage is merged as `d51b5023ede27bcf0c66670620e86643a1b07038`.
- Object PR #111 has now completed the real `GenericDatabasePage` Relation picker/editor migration through `GenericDatabasePageServices.relationEditor`.
- PR #114 `Cover Relation lifecycle in real database host` is merged as `a152c4984331789af8450bfe10ed62a4bea0cce1`.
- `lib/views` no longer contains a user-facing direct `ObjectStore.setRelation()` call; real page writes route through the canonical Relation editor/mutation facade.
- Object PRs #112/#113/#115 are Object inspector/Body integration and do not change Relation lifecycle.
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

## Checkpoints completed in this sustained run
1. Re-read AGENTS.md, Issue #56, repository handoff, Relation handoff, latest main/PR/CI.
2. Detected that Object PR #111 had landed the previously blocked real-host `GenericDatabasePage` integration.
3. Reviewed the #111 Relation picker patch and confirmed load/save now use `GenericDatabasePageServices.relationEditor` and diagnostics are rendered read-only before explicit save.
4. Re-audited `lib/views` and confirmed the old direct `ObjectStore.setRelation()` user-facing write is gone.
5. Opened PR #114 from `feature/relation-real-host-regressions`.
6. Added real-page widget coverage proving explicit bidirectional save synchronizes the inverse Property.
7. Added real-page missing-target coverage proving diagnostics are visible and cancel preserves the legacy missing id unchanged.
8. Added real-page single-cardinality coverage proving diagnostics are visible and cancel preserves the legacy multiple values unchanged.
9. Added a stale-picker race regression: delete a candidate after picker load, then save; the real page fails closed, surfaces the update error, and leaves source Relation/index state unchanged.
10. First latest-head CI attempt stopped at analyzer because the new stale-picker test had one unused import; removed it immediately.
11. Corrected head `e3b357c5427e43d4ba248d2391ffe73e48253812` passed dependency install, Drift generation, `flutter analyze`, and the full test suite in Flutter CI #620.
12. Object PR #115 advanced main with Body-only changes; confirmed non-overlap, then squash-merged PR #114 as `a152c4984331789af8450bfe10ed62a4bea0cce1`.

## Validation
- PR #114 corrected head `e3b357c5427e43d4ba248d2391ffe73e48253812`: Drift generation — success; `flutter analyze` — success; full test suite — success (Flutter CI #620).
- PR #114 earlier head failed only on one unused test import before tests; no Relation implementation failure was observed.
- PR #109 head `576346d836c2ad07c3f2a590640751dd8b107741`: Drift generation, analyze, full tests — success (Flutter CI #597).
- Previous Relation PRs #66/#69/#73/#74/#75/#80/#81 were CI-green before merge.
- Local Flutter execution remains unavailable in this connector-only lane; GitHub Actions is the executable validation source.

## Exact next actions
1. Treat the real `GenericDatabasePage` Relation editor acceptance path as integrated and covered; do not create another parallel picker/editor abstraction.
2. Resume Relation implementation only when real-host usage exposes a concrete lifecycle/read/index/backlink regression; start with a focused failing test.
3. Keep integrity audit and repair separate. Do not auto-repair missing targets, cardinality conflicts, broken bidirectional values, or other ambiguous user data without explicit product/data policy.
4. Continue Tag hierarchy and legacy mirror changes only through the general Relation APIs.
5. If Object detail later gains Relation editing (not just canonical Relation chips/navigation), reuse the same `RelationTargetService` / `ObjectRelationEditorService` boundaries rather than introducing a second lifecycle path.

## Cross-lane boundary
- `GenericDatabasePage`, Object detail/navigation, Daily Note host integration, Body UI and View/Database navigation remain Object-owned host surfaces.
- The real Database page now consumes the stable Relation boundary correctly; Relation lane should not compete with ongoing Object host work unless fixing a concrete Relation regression.
- `lib/data/object_store.dart` is shared infrastructure; future Relation edits there must stay narrow and refresh latest main first.

## Known risks / blockers
- Low-level generic ObjectStore operations remain intentionally available for persistence internals, corruption simulation tests, and rollback paths; normal user-facing Relation mutations must continue using the canonical facade.
- Missing-target/cardinality/bidirectional-value automatic repair remains intentionally explicit-only because choosing a repair policy can discard user intent.
- Object detail currently consumes canonical Relation presentation/read data; any future editable Relation UI there must preserve the same non-mutating-load / explicit-save contract.

## Stop reason
The newly available Relation work created by PR #111 has been completed: the real Database host lifecycle was audited, four end-to-end Relation safety cases were added, CI passed, and PR #114 was merged. The old user-facing low-level Relation write is gone. No concrete independent Relation correctness gap remains from the current audits; remaining Issue #56 work is Object-owned detail/navigation/Body/Daily Note integration or ambiguous repair policy. This matches AGENTS.md: the Relation lane currently has no remaining actionable independent work until a real integration regression appears.
