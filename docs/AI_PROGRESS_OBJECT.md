# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View daily-use product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement.
- `#149` — Property-row visual polish; deterministic implementation is merged, pending real-host visual validation.
- `#218` — installable macOS `Bookmark.app` / DMG packaging; repository/CI implementation is merged and validated, local user install remains.

`#156` fixed/masonry Gallery is closed/completed. Maintainability/legacy-consolidation is owned by the Refactor lane under `#225`.

## Current integration state
The generic Object/Database/View foundation is live in real hosts. Object work is now daily-use system-collection polish, Object-first presentation parity, identity-safe Weblink/Image workflows, and the final replacement surfaces needed before legacy Bookmark compatibility paths can retire.

Important `main` state through 2026-09-06:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through the generic sidebar/Database path;
- Weblink URL-entry creation is live in the real generic Gallery/List/Table host (#286);
- managed Image import is composed through page services (#287) and wired into the real generic host (#291);
- Weblink/Image title-only identity bypass remains fail-closed;
- fixed/masonry Gallery mode persistence/rendering is integrated;
- generic masonry Gallery dispatches both Weblink Representative Images and canonical Image Objects through shared managed-media components (#223/#284/#288);
- Weblink generated presentation defaults are daily-use oriented (#298);
- Image generated presentation defaults hide the internal managed file path and expose useful provenance metadata (#293);
- generated Weblink Object titles are promoted from resource Page title without overwriting explicit/manual titles (#302);
- direct Weblink creation runs best-effort page metadata/managed-preview enrichment (#303), with Relation lifecycle regression coverage merged in #307;
- managed Image source URL identity is normalized across safely equivalent URL variants (#308);
- Weblink metadata now includes Site name and Favicon URL; Site name participates in generated visible defaults (#309);
- lifecycle Bookmark rows, Notion cards, and reverse-lookup thumbnails are already routed through the canonical `BookmarkVisualImage` path (#296/#294/#299);
- Refactor #310 extracted `GenericDatabasePage` read/projection loading while preserving product behavior;
- deterministic shared six-dot Property handle/grid is merged (#205);
- macOS release packaging from #220 is integrated and CI-built successfully.

## Completed in the current sustained Object sequence
### #286 — canonical Weblink URL-entry host
Merged. Real generic Gallery/List/Table create affordances now use `URLを追加`, submit through canonical normalization/reuse, and reopen the same Object through shared opening-mode behavior. Board creation stays hidden for identity-sensitive system modes.

### #287 / #291 — canonical managed Image import
Merged. Generic page services expose the managed Image import composition root and the real generic host now uses it. Picker cancellation is a no-op; successful import reloads and opens the canonical Image. Raw title-only Image creation is still rejected.

### #288 — managed Image media dispatch
Merged. Shared `WeblinkGalleryMedia` now recognizes the canonical Image ObjectType and delegates to `ImageGalleryMedia`; custom ObjectTypes remain media-free.

### #293 / #298 / #302 — daily-use Image/Weblink presentation defaults
Merged. Image defaults expose filename/note/content type/source URL instead of the internal managed path. Weblink defaults emphasize Page title / Site name / Domain / Description / URL, and generated domain titles promote to fetched Page titles without overwriting user-owned titles.

### #296 / #299 and related Refactor slices
Merged canonical visual migration now covers lifecycle rows and reverse lookup, while Refactor also migrated the Notion card in #294. The remaining Stage1 List/Table direct visual helper is currently owned by open Refactor PR #304.

### #303 / #307 — direct Weblink enrichment lifecycle
Merged. Direct generic collection creation now enriches page metadata after canonical identity exists and delegates preview ingestion to the existing production Weblink -> Image pipeline. Relation-lane regression verifies normalized reuse, Representative-image idempotency, backlinks/index and workspace audit.

### #308 — managed Image source URL identity hardening
Merged. Safe-equivalent source URL variants normalize before reuse; query/fragment remain identity-significant; malformed pre-existing provenance does not block unrelated valid creation.

### #309 — Site name / Favicon metadata
Merged. Metadata extraction captures `og:site_name` and favicon URLs, resolves relative media URLs, stores reusable Weblink metadata, and upgrades only historical generated defaults while preserving user customizations.

## Active Object PR
### PR #311 — `Make shared URL properties safely clickable`
Branch: `feature/object-clickable-url-properties-56`
Head before this handoff refresh: `518c0d9b6f10a635bdd38d224f50ca02df653c8c`.

Current slice:
- shared `ObjectPropertyValueView` makes valid absolute HTTP(S) URL Properties interactive;
- default production behavior opens through `url_launcher` using external-application mode;
- invalid/non-HTTP values remain ordinary non-interactive text;
- injected opener seam keeps widget coverage platform-plugin-free;
- this automatically benefits generic Database Table/List/Gallery Property rendering and shared Object detail rendering without a Weblink-specific page.

CI run #1221 started from the pre-handoff head. This documentation commit will advance the branch and trigger a fresh run; always evaluate CI for the latest PR head before integration.

## Discovered next presentation gap
The shared `WeblinkGalleryMedia` already supports both `GalleryViewMode.fixed` and `masonry`, and dispatches canonical Image Objects to `ImageGalleryMedia`. However the real `GenericDatabasePage._gallery` currently wraps the shared media widget in `if (mode == GalleryViewMode.masonry)`, so fixed Gallery cards do not show managed Weblink/Image media.

The product fix is intentionally tiny: host the same shared media component in fixed mode as well and add a real-host fixed regression. Do not redesign Gallery or add another media path.

Tooling note for this chat: GitHub connector file writes replace the entire file and local git has no DNS access, so a one-line edit to the large shared hotspot should not be forced through an unsafe hand-reconstructed whole-file replacement. Revisit when a safe patch-capable path is available, or when another sequenced edit to that host already provides the full file safely.

## Exact next Object actions
1. Finish latest #311 Analyze/Test, fix any issue, and integrate if green/mergeable.
2. Add the fixed-Gallery real-host managed-media call by removing the masonry-only host gate when a safe patch path is available; cover both Weblink and Image fixed presentation without changing identity/opening semantics.
3. Continue #155 generic Weblink/Image daily-use polish through shared components, not feature-specific pages. Candidate: useful resource metadata/presentation only where it materially improves real use.
4. After Refactor #304 lands, re-audit remaining production `BookmarkItem.coverPhoto` / `thumbnail` presentation references and migrate only truly user-facing residual surfaces through `BookmarkVisualImage`.
5. Sequence legacy URL/remote-thumbnail retirement with Refactor only after Object-first presentation parity is proven.
6. Validate #205 six-dot alignment in the user's actual app/theme and close #149 only after visible confirmation.
7. Complete #218 local install/data-preservation check when the user is ready.

## Cross-lane boundaries
### Relation lane
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature.
- #307 covers the newest direct-Weblink-enrichment Relation-producing workflow.
- #311 is presentation-only and introduces no Relation write/read semantic changes.
- Resume Relation implementation only for a genuinely new Relation-producing workflow or a concrete correctness regression.

### Refactor lane — #225
- Refactor owns maintainability guardrails, migration extraction, failure-policy cleanup, legacy inventory, and behavior-preserving technical-debt reduction.
- Refactor #310 has already extracted `GenericDatabasePage` read/projection loading.
- Current open Refactor PR #304 owns only `lib/views/bookmark_unified_stage1_page.dart` plus its focused visual regression; Object lane must not edit that host until #304 resolves.
- `generic_database_page.dart` currently has no open-PR owner, but any Object change there should remain deliberately tiny because Refactor is actively decomposing hotspots.
- Object lane owns product-semantic replacement surfaces; Refactor may delete/relocate legacy paths only after Object-first parity is proven.

## Risks / blockers
- Large shared hosts create merge-conflict and accidental-rewrite risk; prefer true patch-sized edits and explicit ownership sequencing.
- Legacy Bookmark URL/thumbnail storage remains compatibility data while old production hosts still depend on it; do not delete it early.
- Identity-sensitive Weblink/Image creation must not fall back to generic title-only creation.
- Rich media presentation must reuse managed Image/Weblink identity, canonical Relation reads, and persisted geometry rather than create parallel state.
- External URL launching must remain restricted to safe explicit URL semantics; do not treat arbitrary text/custom schemes as clickable web links by default.
- Changing macOS Bundle Identifier can change sandbox location; preserve #220 data-safety behavior.

## Validation
- #286/#287/#288/#291/#293/#296/#298/#302/#303/#307/#308/#309 were integrated after their relevant Analyze/Test checks.
- #308 replacement PR carried the final identity change after the superseded branch diverged.
- #311 has dedicated widget regressions for valid HTTP(S) tapping and rejection of `javascript:` URL-like values; latest-head CI must be checked after this handoff commit.

## Stop reason
No product blocker is known. Continue with #311 integration and then the next safe non-conflicting #155/#56 presentation slice. The fixed-Gallery host gap is known but should not be implemented through an unsafe whole-file rewrite merely to bypass the current connector's lack of patch editing.
