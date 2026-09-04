# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery presentation.
- `#149` — Property handle alignment; implementation merged, real-host visual validation remains.

`#166` (Object aliases) is closed as completed.

## Current implementation position
The generic Object/Relation architecture is integrated into real Database/Object hosts. Relation work is mature and no independent Relation implementation slice is currently pending. The dominant remaining work is Object-owned product exposure and presentation.

Recent Object progress on `main`:
- #199 — Bookmark detail cover consumes managed Weblink/Image visual resolution.
- #203 — system Weblink collection is exposed as `Weblinks` through the existing generic sidebar/Database navigation list.
- #204 — persisted per-View `GalleryViewMode.fixed | masonry` in `settings['galleryMode']` while keeping one `layoutType = gallery` semantic.
- #205 — deterministic shared 2x3 Property drag handle + explicit first-line layout grid.
- #206 — shared `ObjectGalleryView` fixed/masonry renderer plus Gallery-only toolbar selector; Flutter CI #846 green and merged.

The next highest-value gap is real `GenericDatabasePage` consumption of #206: the production Gallery host still uses its legacy fixed `GridView.builder`, so persisted mode switching is not yet end-to-end in the real host.

## Issue #155 production state
### Bookmark -> Weblink
Live on `main`:
- canonical `Bookmark -> Weblink` through `ObjectSyncService` / `RelationMutationService`;
- conservative URL normalization/reuse;
- verification-first direct Object URL retirement while legacy `bookmarks.url` remains compatibility data;
- Weblink-owned core metadata.

### Managed Image / Weblink -> Image
Live on `main`:
- app-managed remote image storage;
- managed Image Object identity/provenance/reuse;
- production `Representative image` single Relation(Image) and `Related images` multi Relation(Image);
- real preview pipeline and real app-host background ingestion;
- canonical `BookmarkVisualResolver` through `RelationReadService`;
- Bookmark detail cover wired to managed visual resolution (#199);
- Relation lifecycle coverage through real pipeline/host boundaries.

### First-class navigation
- #203 exposes `Weblinks` through the same generic sidebar/Database path used by user-created Databases.
- No Weblink-specific page or persistence model was introduced.

Remaining #155 work is primarily:
- remaining Bookmark Gallery/Table/card managed visual migration;
- polished generic Weblink Table/Gallery/List presentation and real-app verification;
- rich Weblink/Image presentation, ideally converging with #156 Gallery work;
- eventual legacy URL/remote-thumbnail compatibility retirement after equivalent Object-first hosts are proven.

## Object identity / aliases — completed (#166)
Alias persistence, shared identity search, detail editing, Body reference resolution, alias-aware Relation candidate search, real Relation picker consumption and ambiguity/target-type regressions are merged. References persist canonical Object ids only.

## Integrated Relation foundations
Canonical Relation mutation/read/index lifecycle, backlinks, target/cardinality validation, safe deletion/detach, integrity audit/reconcile, stale metadata guardrails, alias-aware picker integration and real managed-preview workflow regressions are on `main`.

No Weblink-specific Relation service, alternate index, or direct serialized-id persistence path exists.

Relation lane should resume only when Object lane introduces a new Relation-producing workflow or a concrete Relation correctness regression appears.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Database collection filtering and View filtering are separate stages.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Value, Object Relation and Computed remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local options.
- Date is a Value; Daily Note is an Object keyed by date.
- Weblink stores resource-derived facts; Bookmark stores user-specific organization/evaluation and relates to Weblink.
- User-facing Relation writes and Relation-affecting deletion use canonical Relation APIs.
- Aliases are search/presentation metadata; references and Relations persist canonical Object ids.

## Delivery priorities
1. Object lane: wire #206 into the real `GenericDatabasePage` Gallery host with a small patch, reusing its existing card builder/opening/Property behavior.
2. Object lane: add real-host #156 regression for persisted fixed/masonry switching and mixed media geometry.
3. Object lane: finish #155 managed visual migration across remaining Bookmark/Table/Gallery/card surfaces and polish generic Weblink collection presentation.
4. Object lane: validate #205 in a real-host screenshot; close #149 only after visible alignment is confirmed.
5. Continue retiring legacy Bookmark-specific paths only after equivalent Object-first hosts are proven.
6. Relation lane: resume only for new Relation-producing workflows or concrete regressions.
7. Use the app actively and derive further Object/Database/Body work from real friction.

## Validation status
Recent relevant green CI:
- #203 Flutter CI #845 — success.
- #206 Flutter CI #846 — Drift generation, analyze and full tests success.
- Earlier recent Relation/Object validation includes #192 #798, #195 #811, #198 #819, #200 #823, #201 #825, #202 #828.

## Known risks / sequencing constraints
- `GenericDatabasePage` is a large hotspot. Prefer a patch-capable edit for #156 host integration rather than reconstructing/replacing the entire file through a connector-only contents write.
- Do not introduce feature-specific Relation persistence; reuse canonical Relation services.
- Do not silently repair ambiguous Relation damage; only deterministic index-only drift is automatically reconcilable.
- Legacy Bookmark URL/thumbnail retirement remains verification-first and non-destructive.
- Managed media Relations are written only after valid managed Image Object ids exist.
- #156 Gallery geometry is presentation/View-setting work and must not duplicate Object identity or Relation state.

## Current lane status
Object lane completed the latest safe integration checkpoints: #203 sidebar Weblinks merged and #206 shared Gallery renderer/control merged. The next exact step is the small real-host `GenericDatabasePage` Gallery patch. Relation lane has no independent pending work.
