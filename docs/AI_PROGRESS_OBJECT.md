# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#149` — Property-row visual polish; deterministic implementation is merged, pending real-host visual validation.
- `#218` — installable macOS `Bookmark.app` / DMG packaging; repository/CI implementation is merged and validated, local user install remains.

`#156` fixed/masonry Gallery is complete and closed after #223.
Maintainability/legacy-consolidation work is owned by the separate Refactor lane under `#225` and `docs/AI_PROGRESS_REFACTOR.md`.

## Current integration state
The generic Object/Database/View foundation is integrated into real hosts. Object work is now primarily daily-use presentation, identity-safe system-Object creation/import UX, and completing the Object-first replacement surfaces needed before legacy Bookmark paths can retire.

Important `main` state:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks / Images / Daily Notes are exposed through the existing generic sidebar/Database path (#203/#213);
- generic Daily Notes creation preserves one Object per local date (#214);
- generic Weblink/Image title-only and Board creation fail closed instead of bypassing canonical URL/file identity (#215);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are complete (#204/#206/#212/#223);
- managed Image dimensions and canonical Weblink visual geometry are live (#207/#209/#217/#221/#223);
- managed Image Gallery read-only presentation foundation is merged (#284);
- identity-aware generic collection create-mode classification is merged (#285);
- deterministic shared six-dot Property handle/grid is merged (#205);
- exposed Weblink/Image Relation editing/backlink/delete lifecycle is covered through #208/#210/#211/#216/#222;
- macOS packaging from #220 is merged and the main-push macOS workflow successfully built/uploaded both the release app and DMG.

## Completed this Object run
### #223 — real managed Weblink media in masonry Gallery
Merged to `main` as `72ed6f6dc26e00e92e5753578ea72b9500d30311`.

This completed #156:
- real `GenericDatabasePage` masonry cards consume `WeblinkGalleryMedia`;
- managed Representative-image geometry is driven by persisted Image dimensions without eager full-resolution decoding for layout;
- portrait/landscape geometry, stable fallback and canonical Object opening are regression-covered;
- final Analyze/Test CI passed before merge;
- Issue #156 is closed as completed.

### #284 — managed Image Gallery media foundation
Merged to `main` as `56441ba951369b4d3461bb3bb08aa53ba0bbc511` after Analyze/Test passed.

This #155 presentation foundation:
- adds read-only canonical managed Image visual resolution;
- exposes persisted Image geometry without decoding bytes for layout;
- adds reusable `ImageGalleryMedia` fixed/masonry/fallback presentation coverage;
- does not yet insert Image media into the real `GenericDatabasePage` host.

### #285 — identity-aware collection create modes
Merged to `main` as `59f32bc80e31ca0b7a2319eaec7b1ecd626f8748` after Analyze/Test passed.

This #155 creation foundation:
- adds typed `GenericDatabaseCreateMode` classification to `GenericDatabaseObjectCreateService`;
- centralizes system collection creation semantics instead of duplicating system-key checks in presentation hosts;
- classifies Weblink as URL-entry, Image as managed-file import, Daily Note as date-keyed creation, and normal ObjectTypes as generic creation;
- adds focused in-memory coverage for all four modes.

## Active Object PR
### PR #286 — `Add canonical Weblink URL entry in generic host`
Branch: `feature/object-weblink-url-entry-155`
Base: `main`.

Current slice:
- real Gallery/List/Table create affordances show `URLを追加` for Weblink collections;
- Weblink creation opens a URL-specific dialog and writes only through canonical `createWeblinkFromUrl()` normalization/reuse;
- created/reused Weblinks reopen through the existing shared Object opening-mode path;
- normal immediate creation and Daily Note behavior remain unchanged;
- managed Image creation remains fail-closed until the dedicated file import slice;
- Board create-in-group is hidden for identity-sensitive system collection modes;
- a real `GenericDatabasePage` regression covers URL normalization and canonical reuse.

No direct Relation mutation/index/backlink path is introduced.

## Exact next Object actions
1. Finish #286 Analyze/Test; fix any regression, then integrate the canonical Weblink URL-entry host slice.
2. Insert the already-merged #284 `ImageGalleryMedia` into the real `GenericDatabasePage` Gallery in a small patch, preserving Object opening and existing Weblink media behavior.
3. Add the managed Image file-picker/import affordance as a separate identity-safe slice; do not create raw title-only Images.
4. Continue #155 legacy Bookmark visual migration in small patches that do not conflict with Refactor work; prefer existing `BookmarkVisualImage` / canonical resolver.
5. Polish generic Weblink/Image Table/Gallery/List/detail defaults through existing ObjectType/View contracts rather than feature-specific pages.
6. Validate #205 six-dot alignment in the user's actual app/theme and close #149 only after visible confirmation.
7. Complete #218 local install/data-preservation check when the user is ready.

## Cross-lane boundaries
### Relation lane
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature.
- Exposed Weblink/Image Relation host coverage is integrated through #222.
- #284/#285/#286 are Object-owned presentation/creation work and introduce no direct Relation writes.
- Resume Relation implementation only for a new Relation-producing workflow or concrete correctness regression.

### Refactor lane — #225
- Refactor owns maintainability guardrails, migration extraction, failure-policy cleanup, legacy inventory and behavior-preserving technical-debt reduction.
- Current open Refactor PR #283 changes `app_database.dart`, `bookmark_repository.dart`, `saved_view_read_store.dart` and focused tests; it does not currently own `generic_database_page.dart`.
- PR #286 owns a deliberately small `generic_database_page.dart` product patch; broad Refactor edits to that hotspot should remain sequenced until #286 lands.
- Before either lane touches `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, or another hotspot, inspect active PR ownership again.
- Object lane owns product-semantic replacement surfaces; Refactor may delete/relocate legacy paths only after Object-first parity is proven.

## Risks / blockers
- Large shared hosts create merge-conflict risk under parallel Object/Refactor work; prefer patch-sized changes and explicit ownership sequencing.
- Legacy Bookmark URL/thumbnail storage remains compatibility data while old production hosts still use it; do not delete it early.
- Identity-sensitive Weblink/Image creation must not fall back to raw generic title-only creation.
- Rich media presentation must reuse managed Image/Weblink identity and persisted geometry rather than create parallel state.
- Changing macOS Bundle Identifier can change sandbox location; preserve #220 data-safety behavior.

## Validation
- #223 Analyze/Test: passed before merge.
- #284 Analyze/Test: passed before merge.
- #285 Analyze/Test: passed before merge.
- #286: real-host regression added; CI should run from the latest handoff-refresh commit.

## Stop reason
No Object-lane product blocker is known. This handoff was refreshed during an active sustained run; continue through #286 integration and then the next non-conflicting #155 Image presentation/import slice.
