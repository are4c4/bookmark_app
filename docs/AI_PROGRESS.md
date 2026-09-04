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
The generic Object/Relation architecture is integrated into real Database/Object hosts. Relation work is mature; the dominant remaining work is Object-owned product exposure, rich media presentation, and legacy consolidation.

Recent Object progress on `main`:
- #199 — Bookmark detail cover consumes managed Weblink/Image visual resolution.
- #203 — system Weblink collection is exposed as `Weblinks` through the existing generic sidebar/Database navigation list.
- #204 — persisted per-View `GalleryViewMode.fixed | masonry` in `settings['galleryMode']` while keeping one `layoutType = gallery` semantic.
- #205 — deterministic shared 2x3 Property drag handle + explicit first-line layout grid.
- #206 — shared `ObjectGalleryView` fixed/masonry renderer plus Gallery-only toolbar selector.
- #207 — managed Image pixel width/height metadata for presentation geometry.
- #209 — shared read-only `WeblinkVisualResolver`; `BookmarkVisualResolver` reuses the same canonical Weblink -> Representative image lookup path. Flutter CI #857 green; merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 — real `GenericDatabasePage` Gallery consumes persisted fixed/masonry mode through `ObjectGalleryView` while preserving the existing card builder/opening/Property behavior. Flutter CI #862 green; merged as `232b55bc5677c5415dd49db361a902a2f2f454b6`.

The former highest-value #156 gap — real GenericDatabasePage consumption of the shared Gallery renderer — is now closed. Remaining #156 work is actual managed media aspect-ratio sizing and mixed portrait/landscape real-host coverage.

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
- canonical read-only Weblink visual resolution through `RelationReadService` (#209);
- Bookmark visual resolution reuses the same Weblink visual path;
- Bookmark detail cover wired to managed visual resolution (#199);
- Relation lifecycle coverage through real pipeline/host boundaries.

### First-class navigation
- #203 exposes `Weblinks` through the same generic sidebar/Database path used by user-created Databases.
- No Weblink-specific page or persistence model was introduced.

Remaining #155 work is primarily:
- migrate remaining legacy Bookmark Gallery/card/reverse-lookup thumbnail hosts to `BookmarkVisualImage` / canonical resolver;
- polished generic Weblink Table/Gallery/List presentation;
- rich Weblink/Image presentation converging with #156 media-driven masonry work;
- eventual legacy URL/remote-thumbnail compatibility retirement after equivalent Object-first hosts are proven.

## Object identity / aliases — completed (#166)
Alias persistence, shared identity search, detail editing, Body reference resolution, alias-aware Relation candidate search, real Relation picker consumption and ambiguity/target-type regressions are merged. References persist canonical Object ids only.

## Integrated Relation foundations
Canonical Relation mutation/read/index lifecycle, backlinks, target/cardinality validation, safe deletion/detach, integrity audit/reconcile, stale metadata guardrails, alias-aware picker integration and real managed-preview workflow regressions are on `main`.

Relation PR #211 is currently active tests-only coverage for Bookmark backlinks in the exposed Weblink generic host. Object lane should avoid broad Relation lifecycle edits while it is active.

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
1. Object lane: migrate remaining real Bookmark visual hosts (especially `NotionBookmarkCard` / Stage1 and reverse-lookup dialog) to existing `BookmarkVisualImage` / resolver without changing card semantics.
2. Object lane: feed #207 persisted Image dimensions + #209 shared Weblink visual resolution into real masonry Gallery media geometry; add portrait/landscape real-host regression and stable no-media fallback.
3. Object lane: polish generic Weblink Table/Gallery/List presentation using existing ObjectType/View/default contracts rather than a Weblink-specific page.
4. Object lane: validate #205 in a real-host screenshot; close #149 only after visible alignment is confirmed.
5. Continue retiring legacy Bookmark-specific paths only after equivalent Object-first hosts are proven.
6. Relation lane: complete/merge its current tests-only exposed-Weblink backlink regression, then resume only for new Relation-producing workflows or concrete regressions.
7. Use the app actively and derive further Object/Database/Body work from real friction.

## Validation status
Recent relevant green CI:
- #209 Flutter CI #857 — success.
- #212 Flutter CI #862 — success.
- #203 Flutter CI #845 — success.
- #206 Flutter CI #846 — Drift generation, analyze and full tests success.
- Earlier recent Relation/Object validation includes #192 #798, #195 #811, #198 #819, #200 #823, #201 #825, #202 #828.

## Known risks / sequencing constraints
- Remaining Stage1 Bookmark visual migration touches a large hotspot. Prefer a patch-capable edit rather than reconstructing/replacing the entire file through connector-only contents writes.
- Do not introduce feature-specific Relation persistence; reuse canonical Relation services.
- Do not silently repair ambiguous Relation damage; only deterministic index-only drift is automatically reconcilable.
- Legacy Bookmark URL/thumbnail retirement remains verification-first and non-destructive.
- Managed media Relations are written only after valid managed Image Object ids exist.
- #156 media geometry must reuse managed Image metadata/visual resolution and must not duplicate Object identity or Relation state.

## Current lane status
Object lane merged #209 shared Weblink visual resolution and #212 real GenericDatabasePage fixed/masonry Gallery integration, then synchronized #156 and lane handoffs. The next exact work is a small real-host Bookmark visual migration patch, followed by media-driven masonry sizing. Relation lane has one active tests-only exposed-Weblink backlink PR (#211).
