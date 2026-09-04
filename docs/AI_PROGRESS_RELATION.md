# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, relation write validation, rename/delete propagation, target constraints, stale/inconsistent metadata handling, Tag hierarchy through Relations, and reusable Relation APIs consumed by Object-owned hosts.

## Active Issues
- `#155` — Architecture: make Weblink a reusable Object and relate Bookmarks to it
- `#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current goal
Keep Weblink Objectization on the existing generic canonical Relation boundary. Production Bookmark -> Weblink and Weblink -> Image schemas now exist; Relation lane validates lifecycle/index/backlink/audit behavior and must not introduce a Weblink-specific Relation persistence path.

## Current state
- Generic Relation foundations through #109/#114 remain merged and stable.
- #155 canonical boundary coverage #174/#175/#176/#177 is merged.
- Object #179 made `Bookmark -> Weblink` a production single Relation in the real `ObjectSyncService` path and writes only through `RelationMutationService`.
- Relation #182 (`79fadb883d026de7111d101547a45e1b03e40e3a`) locks live URL retarget and invalid-URL detach.
- Relation #184 (`c2dd18aef645397346bb3f7d9071ecd64368b898`) locks live Weblink Relation-safe deletion.
- Relation #188 (`bcb153a5ddfcd4b82f3a6bebd8efeb0790c0ca89`) locks shared-Weblink deletion across two Bookmarks and deterministic index-only reconcile.
- Object #185 preserves native Image/Bookmark Objects during legacy mirror cleanup while stale mirrors still use Relation-safe deletion.
- Relation #190 (`799a4ecaf554f8574ae7792f0a91e42004c41280`) proves native Image Relation targets survive compatibility sync and stale mirrored Image cleanup preserves surviving targets.
- Object #191 (`46287873a97dad00db408f64f589b0d0ee8740a6`) added production `Representative image` single Relation(Image) and `Related images` multi Relation(Image) schema through `WeblinkImageSchemaService`.
- Relation #192 (`c0179751f22083552e253344626498527f111e25`) exercises those production Properties directly through canonical mutation, idempotency, backlinks/index/audit, and Relation-safe Image deletion.
- Issue #155 Relation-lane acceptance is fully checked through #192.
- No open PR remains at this handoff.
- No Weblink-specific Relation service/index/serialization/repair path has been introduced.

## Canonical APIs / contracts
### Mutation
- `RelationMutationService.setRelation(...)`
  - re-resolves persisted Property metadata;
  - validates source/target ObjectType, target existence, same-workspace constraints and cardinality;
  - persists Relation values and replaces normalized edges canonically;
  - repeated identical assignment is idempotent.
- `RelationMutationService.deleteObject(...)`
  - rebuilds/discovers incoming Relation state;
  - validates detach plans first;
  - detaches surviving sources through canonical mutation;
  - deletes the target only after Relation values/indexes are safe.

### Read / index / integrity
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` remains read-only.
- `RelationIndexReconcileService` repairs deterministic index-only drift from persisted Relation values and refuses ambiguous missing-target/cardinality repair.
- Direct persisted Relation-id serialization is prohibited in user-facing workflows.

## #155 Relation checkpoints
1. #174 — Bookmark -> Weblink canonical attach, repeat idempotency, shared target, detach/delete.
2. #175 — Weblink representative/related Image single/multi target/cardinality/stale-metadata rules plus audit/reconcile.
3. #176 — Image deletion detaches incoming Weblink image Relations while preserving unrelated targets.
4. #177 — stale caller metadata cannot override canonical target/cardinality; ambiguous missing target repair fails closed.
5. #182 — real Object sync retargets Weblink correctly and invalid URLs detach without stale edge/backlink state.
6. #184 — production Weblink deletion leaves surviving Bookmark with empty Relation and healthy index/backlink/audit.
7. #188 — shared production Weblink deletion detaches every Bookmark; missing index edge reconciles from persisted Relation without resurrecting direct Bookmark URL Value.
8. #190 — native Image targets survive compatibility sync; stale mirrored Image cleanup removes only stale Relation targets.
9. #191 — production Weblink/Image semantic Relation Properties exist with validated target/cardinality.
10. #192 — production Weblink/Image Properties support canonical single/multi writes, repeat idempotency, backlinks/index/audit, and Image deletion lifecycle.

## Validation
- #174 CI #746 — success.
- #175 CI #747 — success.
- #176 CI #748 — success.
- #177 CI #750 — success.
- Object #179 CI #760 — success.
- Object #181 CI #765 — success.
- #182 CI #766 — success.
- #184 CI #771 — success.
- Object #185 CI #782 — success.
- #190 CI #787 — success.
- #188 corrected head `4f7d4a372fd33ef0611dc471f19029613652064e`, CI #790 — success. Earlier #784 failed only due an ambiguous test import and was corrected.
- Object #191 rebased head `6e7c9805496661e3383cd239b0107f491bcc3c30`, CI #796 — success.
- #192 head `a64d74204f4ff02f932ef8112a0f90399fab1130`, CI #798 — Drift generation, `flutter analyze`, full tests — success.

GitHub Actions is the executable validation source in this connector-only environment.

## Cross-lane production state
### Bookmark -> Weblink
Live and Relation-covered:
- find/reuse and URL normalization are Object-owned;
- Relation write is canonical;
- verification precedes mirrored direct Object URL retirement;
- retry, shared target, retarget, invalid detach, deletion and deterministic reconcile are covered.

### Weblink -> Image
Production schema and generic lifecycle are live:
- `Representative image` = single Relation(system Image);
- `Related images` = multi Relation(system Image);
- managed Image identity/provenance exists through Object #189;
- remote bytes storage exists through Object #187;
- native Image survival exists through Object #185;
- canonical Relation lifecycle on the production Properties is covered by #192.

The missing end-to-end piece is Object-owned orchestration that downloads/chooses a preview, creates/reuses the managed Image Object, then calls canonical Relation mutation with that Image id.

## Exact next Relation actions
1. When Object lane lands the real managed-thumbnail -> Image Object -> Weblink Relation workflow, audit it for direct serialized-id or low-level Relation writes.
2. Add focused real-workflow regressions for representative-image idempotency, retry/replacement, related-image preservation, backlinks/index and deletion only if that workflow exists or exposes a concrete defect.
3. Preserve Relation-safe deletion if managed Image lifecycle/removal is introduced.
4. Keep deterministic index-only reconcile separate from ambiguous data repair.
5. Do not create a Weblink-specific Relation facade; continue using canonical generic services.

## Cross-lane boundary
- URL parsing/normalization, metadata acquisition, remote image download/storage, Image Object creation/reuse, system schema/defaults, Bookmark orchestration and presentation are Object-owned.
- Relation lane owns correctness after source id, target id and persisted Relation Property exist, plus focused regressions around Object workflows consuming that boundary.
- Avoid editing Object-owned workflow/core files unless a concrete Relation defect requires a small sequenced fix.

## Known blockers / risks
- No production managed-thumbnail -> canonical Weblink/Image mutation workflow exists yet; therefore there is no additional real workflow for Relation lane to test or repair.
- Automatic repair of missing Weblink/Image targets or cardinality conflicts remains intentionally prohibited because it can discard user intent.

## Stop reason
Issue #155 currently has no remaining independent actionable Relation-lane work. All Relation acceptance items are green/merged through #192, no open PR exists, and the next meaningful Relation checkpoint depends on the Object-owned managed-thumbnail/Image workflow producing real Image ids and invoking the canonical Relation boundary. Continuing independently would duplicate existing generic Relation APIs or cross the explicit Object-lane workflow boundary, matching the AGENTS.md cross-lane dependency stopping criterion.
