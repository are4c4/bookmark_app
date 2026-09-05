# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

## Active issues
- `#155` — reusable Weblink Object + managed Image workflow
- `#56` — generic Object/Database/View integration

`#166` alias-aware Relation picker is complete/closed.

## Current goal
Keep all production Relation behavior behind the canonical Relation subsystem while Object lane exposes more first-class system collections and rich media presentation. When a new user-facing surface appears, add focused real-host coverage for Relation read/write/backlink/delete behavior without creating a feature-specific persistence path.

## Canonical foundation
- `RelationMutationService` is the user-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` only repairs deterministic index drift from persisted Relation values.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional damage is never auto-repaired from editor paths.
- no Weblink/Image-specific Relation persistence service or alternate index exists.

## #155 production coverage
Earlier merged Relation coverage remains valid: #174–#177, #182, #184, #188, #190, #192, #198 and #201 cover Bookmark -> Weblink and Weblink -> Image canonical writes, retry/idempotency, shared targets, retarget, detach/delete, target/cardinality/stale-metadata guardrails, audit and index-only reconcile.

New real-host coverage after system collections became user-facing:
- #208 — exposed `Weblinks` `GenericDatabasePage` edits production `Representative image` single Relation and `Related images` multi Relation canonically; persisted values, edges, backlinks and audit are checked. CI #853 green.
- #210 — deleting an exposed Weblink through the real detail host detaches the surviving Bookmark and leaves audit healthy. CI #855 green.
- #211 (`8d71d5e4581699e51c4e3df538f6945ad4adbe12`) — exposed Weblink detail resolves canonical Bookmark backlinks. Initial CI #859 failed only because the same source title appeared in multiple UI locations; the scoped assertion fix passed CI #890 and merged.
- #216 (`1b0b9bd5a494aecf16e63709db66633e124fe8c4`) — composite real-host Weblink deletion with incoming Bookmark -> Weblink plus outgoing Representative/Related Image Relations: Bookmark survives detached, Image Objects survive, Weblink-origin edges/backlinks disappear, audit stays healthy. CI #891 green.
- #219 was the first Images-host branch but became stale after concurrent Object merges; it was closed without merge after its test itself passed CI #895.
- #222 (`d126650d7fad955462ffe3bd5c540cd4e890da5a`) — clean replay on latest main of the exposed `Images` host lifecycle: the Image detail shows both Weblink backlinks, deleting the Image clears Representative, preserves the other Related Image, removes stale edges/backlinks, and leaves workspace audit healthy. CI #902 green.

Object-owned production pieces consumed by this Relation coverage include #179/#191/#193/#194 plus system collection exposure #203 and #213.

## #166 alias-aware Relation picker — complete
- #195: Relation editor search reuses shared Object identity search and remains canonical target-scoped.
- #200: real `GenericDatabasePage` picker searches aliases, shows alias context and persists canonical Object ids only.
- #202: ambiguous alias + target ObjectType real-host coverage.

## Current exposed Relation surfaces
### Weblinks
Relation-covered in the real generic host for:
- Representative/Related Image editing;
- canonical Bookmark backlink display;
- Weblink deletion with incoming Bookmark Relation;
- composite deletion with outgoing Image Relations;
- healthy values/index/backlinks/audit after mutation.

### Images
After Object #213 exposed `Images` through the generic sidebar, #222 now covers:
- canonical Weblink backlink display for an Image targeted by both Representative and Related Relations;
- Image deletion through the real host;
- surviving Weblink single/multi Relation shrinkage;
- surviving Image edge/backlink preservation;
- healthy audit after deletion.

A lower-level multi-source deletion regression already exists in `weblink_image_relation_delete_lifecycle_test.dart`: multiple Weblinks may reference one Image and canonical deletion detaches every source while preserving unrelated targets. Therefore no duplicate real-host multi-source test is currently needed.

### Daily Notes
Object #213/#214 exposed and date-keyed Daily Notes, but no new Relation-producing workflow was introduced. No Relation-specific implementation is required at this checkpoint.

## Latest audit
Repository search after #222 found no new view-level direct `ObjectStore.setRelation(...)` use. Low-level calls remain in Relation internals and tests/corruption fixtures. Object #221/#223 are read-only Weblink Gallery/media presentation and explicitly do not mutate Relation/index/backlink state.

## Validation
Latest Relation CI:
- #208 CI #853 — success
- #210 CI #855 — success
- #211 corrected CI #890 — success
- #216 CI #891 — success
- #219 CI #895 — success before stale-base replacement; not merged
- #222 CI #902 — success and merged

Earlier important green runs remain #811/#819/#823/#825/#828 for alias and managed-preview host coverage.

## Exact next Relation actions
1. Monitor Object-lane work for a genuinely new Relation-producing workflow: explicit `Related images` population, user-facing URL/Image import that also creates Relations, Object merge/dedup, new first-class Object migration, or new retarget/detach path.
2. Audit every such workflow first for direct serialized ids / low-level `ObjectStore.setRelation` bypass.
3. Add real-host lifecycle/idempotency/backlink/index/delete regression only when the new workflow or concrete bug exists.
4. Keep deterministic index reconcile separate from ambiguous user-data repair.
5. Do not invent automatic Object merge/dedup Relation rewrites without an explicit product policy.

## Cross-lane dependency
Object lane currently owns #155/#156 presentation work. Open #221/#223 consume canonical Relation reads for Weblink managed media but do not create or mutate Relations. Relation lane should not modify their presentation/core files unless a concrete Relation defect appears.

## Notes / risks
- During the #219 clean-replay operation, a transient note file was accidentally created and immediately deleted on `main`; commits `7c656300...` and `0135bdd7...` have net-zero tree effect and contain no product/data change. Do not rewrite main history to remove them.
- Automatic repair of missing targets/cardinality conflicts remains intentionally prohibited.
- Future Object merge/deduplication requires a new explicit Relation policy.

## Stop reason
After #208/#210/#211/#216/#222, the currently exposed Weblink/Image generic hosts are covered for canonical edit/read/backlink/delete lifecycle, and no new production Relation-producing workflow or correctness regression remains. Open Object #221/#223 are presentation-only. This matches the `AGENTS.md` stopping criterion: no independent actionable Relation work remains until Object lane introduces a new Relation-producing surface or a concrete Relation defect appears.
