# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture issues:
- `#56` — generic Object/Database/View integration.
- `#155` — make Weblink a reusable Object and relate Bookmarks to it.

`#166` (Object aliases) is closed as completed.

## Current implementation position
The generic Object/Relation architecture is integrated into real Database/Object hosts. Relation work is mature and no independent Relation slice is currently pending. The dominant remaining work is Object-owned product exposure: managed Weblink/Image presentation, first-class system collection navigation, Gallery/Property polish, and eventual legacy compatibility retirement.

## Issue #155 production state
### Bookmark -> Weblink
Live on `main`:
- #179 `BookmarkWeblinkObjectBridge` in `ObjectSyncService` writes the single `Bookmark -> Weblink` Relation only through `RelationMutationService`.
- #180 conservative URL normalization/reuse.
- #181 verification-first direct Object URL retirement while legacy `bookmarks.url` remains compatibility data.
- #183/#186 Weblink-owned shared metadata.
- Relation #182/#184/#188 cover retarget, invalid detach, single/shared deletion and deterministic index-only reconcile.

### Managed Image / Weblink -> Image
Live on `main`:
- #185 native Image/Bookmark survival during legacy mirror cleanup.
- #187 app-managed remote image storage.
- #189 managed Image Object identity/provenance/reuse.
- #191 production `Representative image` single Relation(Image) and `Related images` multi Relation(Image) schema.
- #192 production-schema canonical mutation/backlink/index/audit/delete lifecycle coverage.
- #193 real `WeblinkPreviewImagePipeline`: preview metadata -> managed storage -> Image Object -> canonical Representative Relation.
- #194 real app-host background preview ingestion without blocking canonical Object sync.
- #196 read-only `BookmarkVisualResolver` using canonical `RelationReadService` with precedence: user cover -> managed Representative Image -> legacy remote fallback.
- Relation #198 covers the real preview pipeline for retry idempotency, Representative replacement, deterministic reconcile and managed Image delete/detach.
- Relation #201 covers the real `ObjectSyncService(enableRemotePreviewImages: true)` host for normalized edge/backlink/audit plus canonical Image deletion detach.

Active Object presentation work:
- #199 — real Bookmark detail cover rendering from managed Images; read-only, no Relation mutation changes.

Remaining #155 work is primarily:
- managed visual host migration across remaining Bookmark/Table/Gallery surfaces;
- first-class Weblink collection/sidebar exposure;
- rich Weblink/Image presentation;
- provider metadata expansion only where useful;
- legacy URL/remote-thumbnail compatibility retirement after Object-first hosts are proven.

## Object identity / aliases — completed (#166)
Merged:
- #171 alias persistence.
- #172 shared canonical-title + alias identity search.
- #173 shared detail alias editing.
- #178 Body Object-reference alias resolution to canonical Object ids.
- #195 Relation candidate search reuses the shared identity service, scopes to persisted target ObjectType and preserves the canonical picker candidate set.
- #200 real `GenericDatabasePage` Relation picker resolves aliases, shows `別名: ...`, guards stale async search responses and saves canonical Object ids only.
- #202 real-host ambiguity/target-type regression: two same-alias valid targets remain visible while a same-alias wrong-ObjectType Object is excluded.

Issue #166 is closed. Future Object merge/deduplication is a separate deferred product workflow.

## Integrated Relation foundations
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, Relation-safe Object deletion, picker diagnostics and real-host regressions are all on `main`.

Recent Relation sequence:
- #174/#175/#176/#177 — core #155 attach/detach/idempotency/target/cardinality/stale-metadata/delete/reconcile contracts.
- #182/#184/#188 — production Bookmark/Weblink retarget/detach/delete/reconcile.
- #190/#192 — native/production Weblink/Image survival and lifecycle.
- #195/#200/#202 — alias-aware Relation search/picker/canonical-id/ambiguity/target-scope behavior.
- #198/#201 — real managed-preview pipeline and real ObjectSync host Relation lifecycle.

No Weblink-specific Relation service, alternate index, or direct serialized-id persistence path has been introduced.

A final Relation audit found no new view-level direct `ObjectStore.setRelation(...)` path. Production Relation writers continue through canonical Relation-layer services/adapters.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Database collection filtering and View filtering are separate stages.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Value, Object Relation and Computed remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local options.
- Date is a Value; Daily Note is an Object keyed by date.
- Weblink stores resource-derived identity/facts; Bookmark stores user-specific organization/evaluation and relates to Weblink.
- User-facing Relation writes and Relation-affecting deletion must use canonical Relation APIs.
- Aliases are search/presentation metadata; references and Relations persist canonical Object ids.

## Delivery priorities
1. Object lane: finish #155 managed Weblink/Image presentation across real hosts and first-class Weblink navigation/collection exposure.
2. Object lane: implement #156 persisted fixed/masonry Gallery modes while reusing the same Object projection/cover/opening behavior.
3. Object lane: finish #149 deterministic six-dot Property handle/layout alignment.
4. Continue retiring legacy Bookmark-specific paths only after equivalent Object-first hosts are proven.
5. Relation lane: resume only for new Relation-producing workflows or concrete Relation correctness regressions; add focused real-host coverage rather than new abstractions.
6. Use the app actively and derive further Object/Database/Body work from real friction.

## Validation status
Recent green CI:
- #192 CI #798.
- #195 CI #811.
- #198 CI #819.
- #200 CI #823.
- #201 CI #825.
- #202 CI #828.

Earlier relevant #155 Relation/Object CI includes #179 #760, #181 #765, #182 #766, #184 #771, #185 #782, #190 #787, #188 corrected #790 and #191 corrected/rebased #796.

## Known risks / sequencing constraints
- Do not introduce feature-specific Relation persistence; reuse `RelationMutationService` and Relation read/index/audit/reconcile services.
- Do not silently repair missing targets or cardinality conflicts; only deterministic index-only drift is automatically reconcilable.
- Alias-aware Relation search must never broaden beyond canonical picker candidates or persist alias strings as identity.
- Legacy Bookmark URL retirement remains verification-first and compatibility data remains non-destructive.
- Native Image cleanup must continue distinguishing first-class no-Legacy-ID Objects from stale mirrored Objects.
- Managed media Relations must only be written after a valid managed Image Object id exists.
- Current #155 presentation/navigation work is read-only/Object-owned unless it introduces a new Relation-producing workflow.

## Current lane status
Relation lane has completed its currently available work through #202. Issue #166 is closed and #155's existing managed-preview Relation workflow is covered through the real host. Remaining open work is Object-owned presentation/navigation/legacy retirement, so Relation should stop until a new production Relation surface or concrete regression appears.
