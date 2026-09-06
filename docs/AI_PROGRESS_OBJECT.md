# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; List readability slices are merged, Bookmark fixed/masonry and Stage1 host spacing remain.
- #245 — legacy Photos -> canonical Image Objects and Image product-semantic convergence.
- #242 — Vault folders designed but lower priority while presentation/Image parity is actionable.

Completed/closed for current scope: #247 Bookmark opening modes, #149 Property handle, #252 Property-add UX, #156 generic fixed/masonry Gallery, #166 aliases.

## Current merged state — 2026-09-06
Latest main observed in this run: `a8c39f6941a9959791b7d36305e921b4e5d0784f` after Object #423.

Recent Object checkpoints:
- #394 merged as `1f26ec2b949fd5960ae719b47bdf0d5731ceee48`: legacy Photo deletion preserves a managed file when a surviving canonical Image owns/shares it while retaining legacy-only cleanup.
- #396 merged as `720c5781b181f92ca4c0a06bb491a2dced052984`: first Photo -> Image promotion skips filesystem-resolvable missing media and retries naturally if the file returns.
- #409 merged as `1024ef2cec5ffa30b9b5abaf60b9327b53021688`: native canonical Image detail can edit Object title and Image `Note` while identity/provenance fields stay protected.
- #415 merged: legacy-owned mirrored Images with `Legacy Photo ID` stay read-only so compatibility sync cannot silently overwrite user edits.
- #413 merged after green CI: generic Image deletion keeps canonical `RelationMutationService.deleteObject(...)` first and then performs fail-closed best-effort managed-file cleanup only when ownership is unambiguous.
- #418 merged: real-host regression proves canonical Image backlinks cover the legacy Photo reverse-lookup concept for Bookmark `Images` + `Cover Image` Relations.
- #416 merged as `442804c8c15c65fd66ed95ccbfde9d20172c48bf` after Flutter CI #1498 green: reusable canonical Image detail preview resolves managed media through `ImageVisualResolver`, uses persisted geometry, resolves profile-relative paths, and fails safely for missing files.
- #423 merged as `a8c39f6941a9959791b7d36305e921b4e5d0784f` after Flutter CI #1512 passed Analyze + the full 708-test suite: generic Images now block user-facing deletion while an Image participates in legacy Photo compatibility ownership, either through non-null `Legacy Photo ID` or as the active `photo_object_links` target. This prevents delete-then-recreate/re-promote loops while leaving `CoreObjectBridge` stale-mirror cleanup intact after the legacy Photo is actually removed.

Broader merged product state remains:
- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live;
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated;
- Bookmark canonical URL and visual presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata;
- Bookmark opening modes use the shared presentation host;
- Bookmark Property rows/add flows are converged;
- Bookmark List metadata hierarchy and bounded chips are integrated;
- legacy Bookmark photo attachments mirror through canonical Bookmark `Images` multi-Relation;
- legacy Bookmark `is_cover` mirrors through canonical Bookmark `Cover Image` single Relation;
- canonical Bookmark cover presentation reads `Cover Image` before legacy explicit-cover fallback;
- canonical Image reimport and Photo promotion use deterministic Image/file identity while preserving legacy compatibility semantics.

## #245 status
Canonical Image identity/import/reimport and Photo -> Image promotion safety are substantially covered. Current product-semantic convergence now includes:
- canonical Bookmark `Images` multi-Relation;
- canonical Bookmark `Cover Image` single Relation;
- canonical cover presentation before legacy fallback;
- native canonical Image title + `Note` editing with mirrored-legacy read-only protection;
- safe legacy Photo file deletion ownership;
- safe canonical Image managed-file deletion ownership;
- compatibility-aware generic Image deletion that blocks active legacy Photo mapping targets;
- canonical Image backlinks covering the legacy Bookmark reverse-lookup concept;
- a reusable canonical Image detail preview presentation component.

Current WIP: #426 `feature/object-image-geometry-refresh-245` adds `ImageObjectService.updateManagedGeometry(...)` so a future canonical Image editor can replace stale persisted `Pixel width` / `Pixel height` after crop/rotate without changing Image identity, File, title, provenance, Photo mapping, or Relations. The branch changes only `image_object_service.dart` and `image_object_dimensions_test.dart`; Flutter CI #1515 is running.

The next editor integration must not simply open `ImageEditorPage` against every canonical Image. Managed files may be shared by another Image, another workspace, or a legacy Photo consumer. Define and test an ownership/copy-on-edit policy first. After editing bytes, re-probe geometry and persist it through the canonical Image geometry mutation. Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary. Do not bypass canonical Relation APIs.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Finish #426 CI and merge it only after green checks and a latest-main non-overlap/mergeability check.
2. Design the smallest canonical Image editor workflow around existing `ImageEditorPage`/`ImageEditService`: resolve the canonical managed file, fail closed or copy-on-edit when ownership is shared/ambiguous, then re-probe and persist Pixel width/height. Do not expose direct shared-file mutation first.
3. Wire #416's reusable canonical Image preview into `ObjectInspectorPage` only through a patch-sized Object-lane change after rechecking live open-PR ownership; do not reconstruct the large shared host through whole-file replacement.
4. Continue #245 canonical Bookmark Image write/edit UX only after deciding how legacy `bookmark_photos` authority is retired or write-through is handled; canonical-only writes are unsafe while compatibility sync can overwrite them.
5. Continue #249 with a patch-sized Stage1 List host slice when a hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
6. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
7. Continue #155 legacy presentation convergence only where a canonical replacement is already proven.
8. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. #413 preserves canonical Relation-safe Object deletion ordering and adds only Object-owned filesystem cleanup afterward. #418 is coverage of existing canonical Bookmark Image Relations/backlinks. #423 adds a pre-delete Object-owned compatibility guard in the generic Images adapter but does not alter Relation persistence/lifecycle; allowed deletions still delegate to `RelationMutationService.deleteObject(...)`. Current Relation PR #420 is handoff-only and does not own Object production files.

### Refactor
Recent Refactor #422/#424 are FTS/docs work and do not overlap current Image production files. Always recheck open PR ownership before editing shared hosts/resolvers. Do not absorb #225 cleanup into Object product PRs.

## Validation in this run
- Rechecked latest main and open PR ownership before production edits.
- Confirmed #423 failure was a test-fixture path-identity mismatch, not production behavior: profile-backed `addPhoto()` stores profile-relative paths while the first fixture created the native Image with an absolute File identity.
- Corrected the fixture to use `database.pathResolver.toStoredPath(...)` and reran the full PR merge-ref suite.
- Flutter CI #1512 passed Analyze and all 708 tests on #423 head `db6313cc6076ca4c3d387b0cb7be151076db0ba1`.
- Squash-merged #423 as `a8c39f6941a9959791b7d36305e921b4e5d0784f`.
- Audited Image editor prerequisites: `ImageEditorPage` mutates file bytes directly while canonical Gallery/detail geometry comes from persisted pixel dimensions.
- Created #426 with only the canonical geometry-refresh mutation and focused regression; no editor UI/file mutation/Relation changes are included.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` and `object_inspector_page.dart` are shared conflict-prone hotspots; changes must be patch-sized and sequenced after live ownership checks.
- The current connector write path replaces complete existing files. Do not reconstruct large Stage1/Inspector/People hosts merely to make a small UI hunk change.
- Generic Images List still uses generic document-icon presentation rather than Image thumbnails; fixing it currently requires the large generic host unless a smaller dispatch seam is introduced safely.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation/file ownership state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.
- Image editing has an additional shared-file hazard: an in-place edit can mutate another canonical Image or legacy Photo consumer even when Object metadata is separate. Resolve ownership/copy-on-edit before exposing the editor.

## Stop / continuation condition
#423 is integrated and #426 is the active safe WIP. Continue #426 to green/merge. After that, prefer Image editor ownership/geometry work that stays in focused services/tests. Shared-host preview/List/Stage1 changes remain intentionally deferred until a hunk-capable edit path is available or another patch-sized seam appears. Do not manufacture parallel persistence/Relation abstractions merely to keep a run busy.
