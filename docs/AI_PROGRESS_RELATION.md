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

Refactoring lane audit:
- Issue #225 explicitly treats the Relation subsystem as mature and out of redesign scope.
- Refactor #227 merged as `20ba50674823190337561c7a97ac16e928b4b009`; it only replaces an empty file-drop enrichment catch with debug/assert visibility and does not change Person creation, Relation mutation, schema, or import success semantics.
- Original guardrail PR #226 was closed rather than force-resolving shared handoff conflicts.
- Replacement #228 merged as `310ec2c5e11edbf97a7f56e13c32120c6cbb51c0`, preserving newer Relation/repository handoff state while adding maintainability/inventory/docs guardrails.
- Refactor #229 merged as `3bf2d895175bcd53381a0feb285b7743d12edd58`; it only makes profile fallback failures visible in debug/assert builds and does not change profile/database/Relation semantics.
- Refactor #230 added the v13 -> current migration regression and its latest head passed Flutter CI #923.
- Refactor #232 then extracted only the `from < 14` saved-view column additions into `migrateToV14(Migrator)`. Relation review confirmed the three `SavedViews` column additions and ordering are byte-for-behavior equivalent; Relation/Object schema and migration sequencing are unchanged.
- Current Refactor #234 changes only `database_view_store.dart` fallback observability plus its test; it declares and appears to preserve Relation behavior.
- Current Refactor #235 is tests-only v12 -> current historical migration coverage.
- normalized Relation index `object_relation_edges` is not part of these historical AppDatabase migration bodies; `ObjectStore` ensures the table/index lazily with `CREATE TABLE/INDEX IF NOT EXISTS`. Current v14/v13 extraction therefore does not move Relation-index migration semantics.
- no new Relation-producing workflow was introduced by the current Refactor work.

## Validation
Latest Relation CI:
- #208 CI #853 — success
- #210 CI #855 — success
- #211 corrected CI #890 — success
- #216 CI #891 — success
- #219 CI #895 — success before stale-base replacement; not merged
- #222 CI #902 — success and merged

Earlier important green runs remain #811/#819/#823/#825/#828 for alias and managed-preview host coverage.

Cross-lane validation observed in the latest audits:
- Refactor #229 — Analyze/Test success before merge.
- Refactor #230 latest head `faa00f34bbb8280e3da40f3d53346a91cd0e7567` — Flutter CI #923 success.
- Refactor #232 — merged after the v13 regression; production diff limited to v14 migration extraction with no Relation semantics change.

## Exact next Relation actions
1. Monitor Object-lane work for a genuinely new Relation-producing workflow: explicit `Related images` population, user-facing URL/Image import that also creates Relations, Object merge/dedup, new first-class Object migration, or new retarget/detach path.
2. Audit every such workflow first for direct serialized ids / low-level `ObjectStore.setRelation` bypass.
3. Add real-host lifecycle/idempotency/backlink/index/delete regression only when the new workflow or concrete bug exists.
4. Keep deterministic index reconcile separate from ambiguous user-data repair.
5. Do not invent automatic Object merge/dedup Relation rewrites without an explicit product policy.
6. Before touching `generic_database_page.dart`, `app_shell.dart`, or `object_inspector_page.dart`, re-check open Object/Refactor PR ownership; while another lane owns one of these hotspots, prefer tests-only or Relation-internal/service work and sequence any necessary UI patch after that PR merges.
7. As Refactor extracts historical `AppDatabase` migrations, audit only migration ordering and any code that actually creates/modifies Relation schema/index state. Do not co-own unrelated version extraction.
8. If Refactor eventually moves the lazy `object_relation_edges` ensure logic out of `ObjectStore`, treat that as a new Relation-owned review point and require index/backlink/reconcile regressions before integration.

## Cross-lane dependency
Object lane currently owns #155/#156 presentation work. Open #221/#223 consume canonical Relation reads for Weblink managed media but do not create or mutate Relations. Relation lane should not modify their presentation/core files unless a concrete Relation defect appears.

Refactoring lane is active under #225. Relation lane must not compete with broad refactors of shared hotspots. In particular:
- `generic_database_page.dart` is currently owned by Object #223 and was explicitly deferred by the Refactor lane;
- `app_shell.dart` and `object_inspector_page.dart` must be re-checked immediately before any non-trivial Relation edit;
- historical migration regression/extraction work is currently Refactor-owned; Relation lane audits sequencing without parallel edits unless Relation schema/index behavior is touched;
- re-check active Refactor PRs before changing `docs/AI_PROGRESS.md`, because Refactor uses it when repository-wide ownership materially changes.

## Notes / risks
- During the #219 clean-replay operation, a transient note file was accidentally created and immediately deleted on `main`; commits `7c656300...` and `0135bdd7...` have net-zero tree effect and contain no product/data change. Do not rewrite main history to remove them.
- Automatic repair of missing targets/cardinality conflicts remains intentionally prohibited.
- Future Object merge/deduplication requires a new explicit Relation policy.
- Refactor extraction must preserve canonical Relation API ownership; do not move Relation semantics into presentation facades or duplicate mutation/index logic during composition cleanup.
- `object_relation_edges` currently remains a Relation-owned lazy normalized index ensured by `ObjectStore`, outside the v12-v14 historical migration extraction path.

## Stop reason
After #208/#210/#211/#216/#222, the currently exposed Weblink/Image generic hosts are covered for canonical edit/read/backlink/delete lifecycle, and no new production Relation-producing workflow or correctness regression remains. Open Object #221/#223 are presentation-only. Current Refactor #234/#235 do not produce Relations; #232 migration extraction was audited and does not touch Relation schema/index semantics. With `generic_database_page.dart` actively owned by Object #223 and no new Relation workflow available, speculative UI/refactor work here would create avoidable conflict. This matches the `AGENTS.md` stopping criteria: no independent actionable Relation work remains until another lane introduces a new Relation-producing surface or a concrete Relation defect appears.
