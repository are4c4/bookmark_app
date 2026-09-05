# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery View modes; media-driven Weblink sizing is the active presentation slice.
- `#149` — Property-row visual polish; deterministic implementation is merged, pending real-host visual validation.
- `#218` — installable macOS `Bookmark.app` / DMG packaging; repository/CI implementation is merged and validated, local user install remains.

Maintainability/legacy-consolidation work is now owned by the separate Refactor lane under `#225` and `docs/AI_PROGRESS_REFACTOR.md`.

## Current integration state
The generic Object/Database/View foundation is integrated into real hosts. Object work is now primarily daily-use presentation, identity-safe system-Object creation/import UX, and completing the Object-first replacement surfaces needed before legacy Bookmark paths can retire.

Important `main` state:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks / Images / Daily Notes are exposed through the existing generic sidebar/Database path (#203/#213);
- generic Daily Notes creation preserves one Object per local date (#214);
- generic Weblink/Image title-only and Board creation fail closed instead of bypassing canonical URL/file identity (#215);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are merged (#204/#206/#212);
- managed Image dimensions and canonical Weblink visual geometry are available (#207/#209/#217);
- deterministic shared six-dot Property handle/grid is merged (#205);
- exposed Weblink/Image Relation editing/backlink/delete lifecycle is covered through #208/#210/#211/#216/#222;
- macOS packaging from #220 is merged and the main-push macOS workflow successfully built/uploaded both the release app and DMG.

## Active Object PR stack — #156 / #155
### PR #221 — `Add managed Weblink media geometry widget`
Branch: `feature/object-weblink-gallery-media-156`
Status: open.

Implements a read-only `WeblinkGalleryMedia` presentation widget that:
- consumes canonical `WeblinkVisualResolver` data;
- verifies the active ObjectType is the system Weblink type;
- uses persisted managed Image aspect ratio for masonry geometry without decoding image bytes for layout;
- keeps fixed-mode media geometry stable;
- provides a deterministic fallback when media/geometry is absent;
- adds in-memory Object/Relation coverage for portrait, landscape, no-media and fixed geometry.

No Object mutation or Relation mutation/index/backlink behavior is introduced.

### PR #223 — `Render managed Weblink media in real masonry Gallery`
Branch: `feature/object-weblink-gallery-real-host-156`
Status: open and stacked on #221.

Real-host insertion is intentionally tiny:
- inserts `WeblinkGalleryMedia` into the existing `GenericDatabasePage` Gallery card builder only for masonry mode;
- keeps fixed Gallery geometry, title/Property rendering, selection and opening behavior unchanged;
- includes a real system-Weblink host regression proving portrait/landscape managed dimensions produce different masonry heights and tapping still opens the same canonical Object.

Because #223 currently owns `generic_database_page.dart`, the Refactor lane must defer broad extraction of that hotspot until this Object stack is merged/rebased and ownership is clear.

## #218 macOS release delivery
PR #220 is merged to `main`.

Merged behavior:
- `tool/package_macos.sh` builds release `Bookmark.app` + `Bookmark-<version>.dmg`;
- default product name `Bookmark`, preferred bundle id `com.are4c4.bookmark`;
- version/build number from `pubspec.yaml`;
- generated local macOS runner when missing;
- existing Bundle Identifier preserved when changing it would hide detected profile data;
- optional one-source AppIcon generation via `sips`;
- optional `--install`, `--open-dmg`, `--configure-only`;
- existing `/Applications/Bookmark.app` is never overwritten automatically;
- main-push/manual CI uploads a `Bookmark-macOS` release artifact.

Validation:
- PR analyze/test succeeded before merge;
- main workflow run `33940306321` completed successfully;
- both `analyze-test` and `build-macos-release` jobs were green;
- release app/DMG build step and artifact upload step both succeeded.

Remaining #218 acceptance is local product validation on the user's Mac: pull current main, run `bash tool/package_macos.sh --install` (or `--open-dmg`), launch `Bookmark.app`, and confirm existing profile data remains visible. Branded artwork remains optional product/design input; the engineering icon pipeline is complete.

## Exact next Object actions
1. Finish #221 CI/integration, then retarget/rebase #223 onto latest main and integrate the real-host masonry slice.
2. Update #156 after #221/#223 land; verify media-driven portrait/landscape geometry and no-media fallback in the actual host.
3. Continue #155 remaining Bookmark visual host migration only in small patches that do not conflict with the Refactor lane; prefer existing `BookmarkVisualImage` / canonical resolver and remove direct legacy thumbnail reads after coverage exists.
4. Add canonical user-facing Weblink URL-entry and managed Image-import affordances for exposed system collections, keeping canonical identity/reuse rules.
5. Polish generic Weblink/Image Table/Gallery/List/detail defaults through existing ObjectType/View contracts rather than feature-specific pages.
6. Validate #205 six-dot alignment in the user's actual app/theme and close #149 only after visible confirmation.
7. Complete #218 local install/data-preservation check when the user is ready.

## Cross-lane boundaries
### Relation lane
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature.
- Exposed Weblink/Image Relation host coverage is integrated through #222.
- #221/#223 are presentation-only and must not introduce direct Relation writes.
- Resume Relation implementation only for a new Relation-producing workflow or concrete correctness regression.

### Refactor lane — #225
- Refactor owns maintainability guardrails, migration extraction, failure-policy cleanup, legacy inventory and behavior-preserving technical-debt reduction.
- Refactor must avoid broad edits to `generic_database_page.dart` while #223 owns it.
- Before either lane touches `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, or another hotspot, inspect active PR ownership.
- Object lane owns product-semantic replacement surfaces; Refactor may delete/relocate legacy paths only after Object-first parity is proven.

## Risks / blockers
- Large shared hosts create merge-conflict risk under parallel Object/Refactor work; prefer patch-sized changes and explicit ownership sequencing.
- Legacy Bookmark URL/thumbnail storage remains compatibility data while old production hosts still use it; do not delete it early.
- Identity-sensitive Weblink/Image creation must not fall back to raw generic title-only creation.
- Rich media presentation must reuse managed Image/Weblink identity and persisted geometry rather than create parallel state.
- Changing macOS Bundle Identifier can change sandbox location; preserve #220 data-safety behavior.

## Stop reason
This handoff was refreshed from current GitHub state. Object implementation remains actionable through the #221/#223 presentation stack and subsequent #155/#156 product work; no Object-lane stop condition is implied by this documentation update.
