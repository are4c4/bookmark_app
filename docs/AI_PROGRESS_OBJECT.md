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
- deterministic shared six-dot Property handle/grid is merged (#205);
- exposed Weblink/Image Relation editing/backlink/delete lifecycle is covered through #208/#210/#211/#216/#222;
- macOS packaging from #220 is merged and the main-push macOS workflow successfully built/uploaded both the release app and DMG.

## Completed this Object run
### #223 — real managed Weblink media in masonry Gallery
Merged to `main` as `72ed6f6dc26e00e92e5753578ea72b9500d30311`.

This completes #156:
- real `GenericDatabasePage` masonry cards consume `WeblinkGalleryMedia`;
- managed Representative-image geometry is driven by persisted Image dimensions without eager full-resolution decoding for layout;
- portrait/landscape geometry, stable fallback and canonical Object opening are regression-covered;
- final Analyze/Test CI passed before merge;
- Issue #156 is closed as completed.

## Active Object PR
### PR #285 — `Expose identity-aware generic collection create modes`
Branch: `feature/object-weblink-url-create-mode-155`
Status: open; CI running at the latest handoff refresh.

This small #155 preparation slice:
- adds typed `GenericDatabaseCreateMode` classification to `GenericDatabaseObjectCreateService`;
- centralizes system collection creation semantics instead of duplicating system-key checks in presentation hosts;
- classifies Weblink as URL-entry, Image as managed-file import, Daily Note as date-keyed creation, and normal ObjectTypes as generic creation;
- adds focused in-memory coverage for all four modes.

No Relation mutation/index/backlink behavior changes.

## Exact next Object actions
1. Integrate #285 after Analyze/Test passes.
2. Wire the typed create mode into the real `GenericDatabasePage` create affordances with a deliberately small host diff:
   - Weblinks: show URL-oriented create UI and call canonical `createWeblinkFromUrl()`;
   - normal collections: preserve current immediate Object creation;
   - Daily Notes: preserve date-keyed open-or-create;
   - Images: remain fail-closed until managed file-picker/import UI is provided.
3. Add a real Weblinks host regression proving URL input creates/reuses one canonical normalized Weblink and opens the same Object.
4. Add the managed Image import affordance as a separate identity-safe slice; do not create raw title-only Images.
5. Continue #155 legacy Bookmark visual migration in small patches that do not conflict with Refactor work; prefer existing `BookmarkVisualImage` / canonical resolver.
6. Polish generic Weblink/Image Table/Gallery/List/detail defaults through existing ObjectType/View contracts rather than feature-specific pages.
7. Validate #205 six-dot alignment in the user's actual app/theme and close #149 only after visible confirmation.
8. Complete #218 local install/data-preservation check when the user is ready.

## Cross-lane boundaries
### Relation lane
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature.
- Exposed Weblink/Image Relation host coverage is integrated through #222.
- #285 and the next URL-entry host slice are Object-owned creation/presentation work and must not introduce direct Relation writes.
- Resume Relation implementation only for a new Relation-producing workflow or concrete correctness regression.

### Refactor lane — #225
- Refactor owns maintainability guardrails, migration extraction, failure-policy cleanup, legacy inventory and behavior-preserving technical-debt reduction.
- Current open Refactor PR #283 changes `app_database.dart`, `bookmark_repository.dart`, `saved_view_read_store.dart` and focused tests; it does not currently own `generic_database_page.dart`.
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
- #285: CI triggered; latest observed run was still in progress while this handoff was refreshed.

## Stop reason
No Object-lane product blocker is known. This handoff was refreshed during an active sustained run; the next implementation dependency is #285 integration followed by a small real-host URL-entry patch.
