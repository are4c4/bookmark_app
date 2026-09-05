# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow while reducing the maintenance cost of the migration period: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image presentation/navigation
- `#156` — fixed/masonry Gallery presentation
- `#149` — Property handle visual validation
- `#218` — installable macOS delivery; implementation merged in #220, local install validation remains
- `#225` — maintainability, hotspot reduction and legacy-path retirement

`#166` alias-aware Object identity / Relation picker work is complete and closed.

## Development lanes
The repository now has three parallel lanes. Each run owns one primary lane and its handoff:
- **Object** — `docs/AI_PROGRESS_OBJECT.md`
- **Relation** — `docs/AI_PROGRESS_RELATION.md`
- **Refactor** — `docs/AI_PROGRESS_REFACTOR.md`

Before editing shared hotspots, inspect open PR ownership. In particular, broad concurrent edits to `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and `app_database.dart` must be sequenced rather than independently rewritten.

## Current implementation position
The generic Object/Relation architecture is integrated into real Database/Object hosts. The project is now mainly in product exposure, rich media presentation, identity-aware Weblink/Image creation UX, local macOS delivery validation, and behavior-preserving consolidation of legacy/maintenance debt.

Recent integration on `main`:
- #199 Bookmark detail uses managed Weblink/Image visual resolution.
- #203/#213 expose Weblinks / Images / Daily Notes through generic sidebar navigation.
- #204/#206/#212 provide persisted fixed/masonry Gallery modes and real-host renderer switching.
- #205 provides the deterministic six-dot Property handle/grid.
- #207 persists managed Image pixel dimensions.
- #209/#217 provide canonical managed Weblink visual resolution + geometry.
- #214 preserves date-keyed Daily Note creation in the generic host.
- #215 fails closed for invalid title-only Weblink/Image generic creation.
- #220 packages Bookmark as an installable macOS app/DMG using a safe local/CI workflow; main macOS CI subsequently built and uploaded the release package successfully.
- Relation real-host coverage expanded through #208/#210/#211/#216/#222 for exposed Weblinks/Images editing, backlinks and deletion lifecycle.
- #225 P0 guardrails landed through #228, including maintainability reporting, no-new-legacy-dependency policy, architecture boundaries, legacy Bookmark inventory, error-policy audit, and a dedicated Refactor handoff.
- #227/#229/#234/#237 improve debug observability for intentional best-effort fallbacks without changing user-visible behavior.
- #230/#232/#235/#236 establish migration regressions and begin extracting historical `AppDatabase` migration bodies safely.

## Object lane — current work
Open presentation stack:
- **#221** adds read-only `WeblinkGalleryMedia` using canonical Weblink visual resolution and persisted Image geometry.
- **#223** is stacked on #221 and inserts that widget into the real `GenericDatabasePage` masonry Gallery with a deliberately tiny host diff and real-host regression coverage.

#223 currently owns `generic_database_page.dart`; broad Refactor extraction of that file is deferred until this stack is integrated/rebased and ownership is clear.

Remaining Object priorities:
- finish #156 media-driven masonry;
- finish #155 managed visual migration/rich Weblink/Image presentation;
- add canonical Weblink URL-entry and Image-import affordances;
- validate #149 in the real host;
- perform the final local #218 install/data-preservation check.

## Relation lane — current state
Canonical mutation/read/index/backlink/audit/reconcile is mature. Real-host Relation coverage includes exposed Weblink and Image collections through #222. Repository audit found no new view-level direct Relation write path requiring a parallel Relation implementation.

Relation should resume only when:
- Object lane introduces a genuinely new Relation-producing workflow;
- a concrete lifecycle/backlink/index correctness regression appears; or
- an active Issue explicitly assigns Relation semantics.

Presentation-only #155/#156 media work is not independent Relation work.

## Refactor lane — #225
The Refactor lane is active and must remain behavior-preserving.

Merged foundations:
- maintainability/LOC/hotspot report;
- no-new-legacy-dependency policy;
- production `BookmarkItem` / `BookmarkRepository` inventory;
- failure-policy audit;
- architecture dependency-boundary documentation;
- multiple fail-soft observability fixes;
- v13/v14 migration safety regressions and v14 extraction;
- v12/v11 migration regression coverage.

Current open Refactor PR:
- **#238 `Extract AppDatabase v13 migration step`** — moves only the v13 migration body behind `migrateToV13(Migrator)` after #235 regression protection; no product/Object/Relation behavior change.

Refactor priorities remain:
1. continue test-before-extraction historical migration cleanup;
2. continue explicit best-effort failure observability;
3. avoid broad `GenericDatabasePage` work while #223 owns it;
4. reduce legacy Bookmark production references only after Object-first parity exists;
5. prefer deletion and narrow responsibility extraction over adding abstraction for its own sake.

## Issue #155 production state
### Bookmark -> Weblink
Live on `main`:
- canonical `Bookmark -> Weblink` through `ObjectSyncService` / `RelationMutationService`;
- normalized Weblink identity/reuse;
- verification-first mirrored direct-URL retirement while legacy `bookmarks.url` remains compatibility data;
- Weblink-owned shared metadata.

### Managed Image / Weblink -> Image
Live on `main`:
- app-managed remote image storage;
- managed Image Object identity/provenance/reuse;
- production `Representative image` single and `Related images` multi Relations;
- real preview pipeline/background ingestion;
- canonical read-only visual resolution and managed Image dimensions;
- Bookmark detail cover rendering.

### First-class system collection UX
Weblinks, Images and Daily Notes use the generic sidebar/Database path. Relation safety for newly exposed collection surfaces is covered in real hosts through #208/#210/#211/#216/#222.

Weblink/Image generic title-only creation still fails closed until dedicated canonical URL/file affordances exist.

Remaining #155 work is primarily presentation and migration:
- remaining Bookmark visual hosts use managed visual resolver;
- rich generic Weblink/Image Table/Gallery/detail presentation;
- canonical user-facing Weblink URL-entry / Image-import creation UX;
- legacy URL/remote-thumbnail compatibility retirement only after Object-first hosts are proven.

## #156 current state
Fixed/masonry View persistence, toolbar, shared renderer, Image dimensions and real-host renderer switching are merged. #221/#223 are the active presentation-only work consuming canonical `RelationReadService`/Weblink visual data to drive real media geometry; they introduce no Relation mutation/index/backlink path.

## macOS release delivery — #218/#220
Merged #220 provides release `Bookmark.app` + DMG packaging, product/bundle identity safety, icon input, install/open helpers, CI artifacts and documentation.

Main workflow run `33940306321` completed successfully: `analyze-test` and `build-macos-release` were both green, including release build/DMG creation and artifact upload. Remaining validation is the user's local install/launch and confirmation that existing profile data remains visible.

Developer ID signing/notarization and App Store distribution remain out of scope for the current personal-use delivery path.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Tags/Weblinks/Images are reusable Objects; lightweight local choices remain Values.
- Daily Note is an Object keyed by unique local date.
- Weblink stores shared resource facts; Bookmark stores user-specific context and relates to Weblink.
- Relation writes/deletions use canonical Relation APIs.
- Aliases are search/presentation metadata; references persist canonical Object ids.
- Identity-sensitive system collections must not fall back to raw title-only Object creation.
- New Object-first feature work should not deepen legacy `BookmarkItem`/legacy-table dependencies unless explicitly required for compatibility/migration.

## Delivery priorities
1. Object: integrate #221/#223 and finish #156/#155 managed media presentation.
2. Refactor: continue #225 migration extraction/error-policy work while avoiding Object-owned hotspots.
3. Object: add canonical URL-entry / managed Image-import affordances.
4. User/product: validate #220 `Bookmark.app` locally and validate #205 visual alignment.
5. Object + Refactor in sequence: retire legacy Bookmark URL/thumbnail presentation after Object-first replacements are proven.
6. Prefer usage-discovered friction and measurable maintenance reduction over speculative abstraction.

## Validation status
Recent Relation CI through #222 is green.
Main macOS release workflow `33940306321` is green, including artifact packaging.
Recent #225 refactor PRs #227/#228/#229/#230/#232/#234/#235/#236/#237 have been integrated through focused analyze/test or migration-regression slices; #238 is currently open and should be judged on its own CI before merge.

## Known risks / sequencing constraints
- Do not introduce direct serialized-id Relation writes from new system-collection/import UX.
- Ambiguous Relation damage is not automatically repaired.
- Future Object merge/dedup requires explicit Relation policy before edge/value rewrites.
- Bundle Identifier changes can change macOS sandbox location; keep #220 data-preservation guard intact.
- Rich Gallery media must reuse existing managed Image/Weblink identity and geometry rather than create parallel media state.
- Historical migration extraction must preserve exact semantics/order and remain protected by regressions.
- Object and Refactor lanes must not concurrently perform broad edits to the same hotspot.

## Current lane status
- **Object:** active on #155/#156 presentation via #221/#223.
- **Relation:** stable/idle until a new Relation-producing workflow or concrete regression appears.
- **Refactor:** active on #225, currently AppDatabase historical migration extraction/error-policy cleanup; broad GenericDatabasePage refactor deferred while #223 owns the host.
