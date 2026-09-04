# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, relation write validation, rename/delete propagation, target constraints, stale/inconsistent metadata handling, Tag hierarchy through Relations, and reusable Relation APIs consumed by Object-owned hosts.

## Active Issues
- `#155` — Architecture: make Weblink a reusable Object and relate Bookmarks to it
- `#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current goal
Keep Weblink Objectization on the generic canonical Relation boundary while Object-owned production schema/workflows arrive. Validate the real Bookmark -> Weblink and Weblink -> Image paths with focused integration regressions; do not add a Weblink-specific Relation persistence layer.

## Current state
- Generic Relation foundation PRs #62/#66/#69/#73/#74/#75/#80/#81/#109/#114 remain merged and stable.
- Issue #155 semantic boundary coverage #174/#175/#176/#177 is merged.
- Object #179 made `Bookmark -> Weblink` a real production single Relation in `ObjectSyncService` and writes only through `RelationMutationService`.
- Object #180/#181 added conservative URL identity and verification-first retirement of the mirrored Bookmark Object's direct URL Value while retaining the legacy database URL compatibility source.
- Relation #182 is merged as `79fadb883d026de7111d101547a45e1b03e40e3a`; it locks live URL retarget and invalid-URL detach integrity through the real Object sync path.
- Relation #184 is merged as `c2dd18aef645397346bb3f7d9071ecd64368b898`; it locks live Weblink deletion through canonical Relation-safe Object deletion.
- Object #185 is merged after Flutter CI #782; native Image/Bookmark Objects without Legacy IDs now survive compatibility cleanup while stale mirrored Objects still use Relation-safe deletion.
- Relation #188 is merged as `bcb153a5ddfcd4b82f3a6bebd8efeb0790c0ca89`; it locks shared-Weblink deletion across two Bookmarks and deterministic index-only reconciliation on the production Bookmark -> Weblink schema.
- Relation #190 is merged as `799a4ecaf554f8574ae7792f0a91e42004c41280`; it proves native Image Relation targets survive legacy compatibility sync and stale mirrored Image cleanup detaches only the stale target.
- Object #191 is merged as `46287873a97dad00db408f64f589b0d0ee8740a6`; production schema now provides `Representative image` single Relation(Image) and `Related images` multi Relation(Image) through `WeblinkImageSchemaService`.
- Relation PR #192 is active and tests the real production Weblink/Image schema through canonical mutation, idempotency, backlinks/index/audit, and Image deletion lifecycle.
- No Weblink-specific Relation service/index/serialization path has been introduced.

## Stable canonical Relation APIs used by #155

### Mutation / lifecycle
- `RelationMutationService.setRelation(...)`
  - re-resolves persisted Property metadata instead of trusting stale caller config;
  - validates source Object ownership, target ObjectType, target existence, and cardinality;
  - persists the Relation value and replaces normalized edges through the canonical boundary;
  - is the only normal write boundary used by the #155 Relation regressions and Object sync path.
- `RelationMutationService.deleteObject(...)`
  - rebuilds the index before deletion;
  - discovers and validates incoming detach plans;
  - detaches surviving sources through canonical `setRelation(...)`;
  - deletes the target only after surviving Relation values/indexes are safe.

### Read / backlinks
- `RelationReadService.backlinks(...)` resolves normalized backlinks to canonical source Objects/Properties.
- `ObjectStore.outgoingRelations(...)` / `backlinks(...)` are used as read-only index observations in regressions, not as alternate mutation APIs.

### Integrity / reconciliation
- `RelationIntegrityService` is read-only and reports missing targets, cardinality problems, index drift, cross-workspace targets, and bidirectional inconsistencies.
- `RelationIndexReconcileService` repairs only deterministic index-only drift from persisted Relation values and refuses ambiguous value repair.

## Issue #155 checkpoints completed
1. #174: existing Bookmark/Weblink ids attach through canonical mutation; repeat assignment is idempotent; multiple Bookmarks can share one target; detach/delete preserve backlink/index integrity.
2. #175: Representative image single and Related images multi Relation(Image) target/cardinality/stale-metadata rules; audit and deterministic reconcile.
3. #176: Image deletion detaches all incoming Weblink image Relations while preserving unrelated Related-images targets.
4. #177: stale caller metadata cannot redirect target/cardinality; missing-target damage is audited and ambiguous reconciliation fails closed.
5. #182: real ObjectSyncService retargets Bookmark -> Weblink without stale old edges/backlinks; invalid URL detaches cleanly; audit stays healthy.
6. #184: deleting the actual production Weblink through `RelationMutationService.deleteObject(...)` leaves the Bookmark alive with an empty Relation and no stale edge/backlink.
7. #188: deleting one shared production Weblink detaches both surviving Bookmarks; simulated missing index edge is rebuilt from the persisted Relation value without resurrecting the retired direct URL Value.
8. #190: native Image targets survive legacy sync; deleting a stale mirrored legacy Image removes only that target from a multi Relation and preserves the native Image edge/backlink/value.
9. #191 dependency is now integrated: production Weblink/Image semantic Relation Properties exist with validated target/cardinality.
10. #192 is the current focused regression using those production Properties directly rather than fixture-created semantic Properties.

## Validation
- #174 Flutter CI #746 — Drift generation, `flutter analyze`, full tests — success.
- #175 Flutter CI #747 — success.
- #176 Flutter CI #748 — success.
- #177 Flutter CI #750 — success.
- Object #179 Flutter CI #760 — success.
- Object #181 Flutter CI #765 — success.
- #182 Flutter CI #766 — success.
- #184 Flutter CI #771 — success.
- Object #185 latest head `80eddc16280956a8b95cffd7c4b581ae765c85c6`, Flutter CI #782 — success.
- #190 head `94eb213a00cba5b5b95f058dcdbd1f56b7be094b`, Flutter CI #787 — success.
- #188 corrected head `4f7d4a372fd33ef0611dc471f19029613652064e`, Flutter CI #790 — success. The prior #784 failure was only an ambiguous `isNull` import in the new test and was corrected.
- Object #191 corrected/rebased head `6e7c9805496661e3383cd239b0107f491bcc3c30`, Flutter CI #796 — success.
- #192 head `a64d74204f4ff02f932ef8112a0f90399fab1130`, Flutter CI #798 — in progress at this handoff update.

GitHub Actions is the executable validation source in this connector-only environment.

## Cross-lane production state
### Bookmark -> Weblink
Production path is now live:
- `BookmarkWeblinkObjectBridge` ensures the single Relation;
- Weblink find-or-create and URL normalization are Object-owned;
- Relation write is canonical;
- Relation/index verification happens before mirrored direct Object URL retirement;
- repeated sync, shared targets, retarget, invalid detach, deletion and reconcile are Relation-regression covered.

### Weblink -> Image
Production schema is now live through Object #191:
- `Representative image` = single Relation(system Image);
- `Related images` = multi Relation(system Image);
- managed Image identity exists through `ImageObjectService`;
- native Image Objects survive legacy mirror cleanup through #185.

Object-owned remaining work is the actual remote-preview/thumbnail workflow that downloads/stores bytes, creates/reuses the managed Image Object, and calls canonical Relation mutation with the resulting Image id. Object PR #187 is remote managed-photo storage groundwork; presentation remains Object-owned.

## Exact next Relation actions
1. Finish PR #192: inspect Flutter CI #798, fix only branch-caused failures, merge when green.
2. When Object lane lands the real managed-thumbnail -> Image Object -> Weblink Relation workflow, audit it for direct serialized-id or low-level Relation writes and add real workflow regressions for representative/related image behavior.
3. Preserve canonical delete/detach semantics when managed Image lifecycle/removal is introduced; add a failing regression first if a concrete defect appears.
4. Keep deterministic index-only reconcile separate from ambiguous missing-target/cardinality repair.
5. Do not add another Weblink-specific Relation facade; use `RelationMutationService`, Relation read/index/audit/reconcile services.

## Cross-lane boundary
- URL parsing/normalization, Bookmark creation/sync orchestration, metadata acquisition, remote image download/storage, Image Object creation/reuse, system schema/defaults, Gallery/Table/detail presentation remain Object-owned.
- Relation lane owns correctness after source id, target id and persisted Relation Property exist, plus regressions around Object-owned workflows that consume that boundary.
- Avoid broad edits to Object-owned workflow/core files while those PRs are active; prefer tests-only Relation slices unless a concrete Relation implementation defect is demonstrated.

## Known risks / blockers
- The real managed-thumbnail workflow has not yet completed the final `Weblink -> Image` production mutation path; #192 can validate the production schema and canonical lifecycle independently, but end-to-end thumbnail ingestion remains an Object dependency.
- Automatic repair of missing Weblink/Image targets or cardinality conflicts remains prohibited because it may discard user intent.

## Stop reason
Not stopped yet. PR #192 is in CI, and the lane should finish/merge it. After that, if no managed-thumbnail Relation workflow has landed and no concrete Relation defect exists, the next safe Relation step is blocked by the Object-owned thumbnail/Image workflow dependency under Issue #155.
