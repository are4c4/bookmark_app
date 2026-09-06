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
Latest main observed in this run: `bc799c123dbdd3313d9d1538f3336721de259b74` after Object #436.

Recent Object checkpoints:
- #394 merged as `1f26ec2b949fd5960ae719b47bdf0d5731ceee48`: legacy Photo deletion preserves a managed file when a surviving canonical Image owns/shares it while retaining legacy-only cleanup.
- #396 merged as `720c5781b181f92ca4c0a06bb491a2dced052984`: first Photo -> Image promotion skips filesystem-resolvable missing media and retries naturally if the file returns.
- #409 merged as `1024ef2cec5ffa30b9b5abaf60b9327b53021688`: native canonical Image detail can edit Object title and Image `Note` while identity/provenance fields stay protected.
- #415 merged: legacy-owned mirrored Images with `Legacy Photo ID` stay read-only so compatibility sync cannot silently overwrite user edits.
- #413 merged after green CI: generic Image deletion keeps canonical `RelationMutationService.deleteObject(...)` first and then performs fail-closed best-effort managed-file cleanup only when ownership is unambiguous.
- #418 merged: real-host regression proves canonical Image backlinks cover the legacy Photo reverse-lookup concept for Bookmark `Images` + `Cover Image` Relations.
- #416 merged as `442804c8c15c65fd66ed95ccbfde9d20172c48bf` after Flutter CI #1498 green: reusable canonical Image detail preview resolves managed media through `ImageVisualResolver`, uses persisted geometry, resolves profile-relative paths, and fails safely for missing files.
- #423 merged as `a8c39f6941a9959791b7d36305e921b4e5d0784f` after Flutter CI #1512 passed Analyze + the full 708-test suite: generic Images now block user-facing deletion while an Image participates in legacy Photo compatibility ownership, either through non-null `Legacy Photo ID` or as the active `photo_object_links` target. This prevents delete-then-recreate/re-promote loops while leaving `CoreObjectBridge` stale-mirror cleanup intact after the legacy Photo is actually removed.
- #426 merged after green CI: `ImageObjectService.updateManagedGeometry(...)` refreshes persisted canonical Image pixel dimensions after byte edits while preserving Image identity, File, title and provenance.
- #432 merged as `07cd55648d6bb62bfdfbea7fe8af880ede9be94b` after Flutter CI #1530 green: `CanonicalImageEditService` coordinates safe edit/restore operations around the existing `ImageEditService`, resolves the canonical File internally, requires exclusive managed-file ownership before in-place mutation, refreshes geometry after success, and rolls bytes back if post-edit metadata persistence fails.
- #434 merged as `53f4b9f5536883918c18213cddc408c88b9d7465` after Flutter CI #1536 green: `CanonicalImageEditService.canEdit(...)` exposes the same canonical File lookup and conservative exclusive-ownership proof as an advisory presentation preflight without treating it as a durable lock.
- #436 merged as `bc799c123dbdd3313d9d1538f3336721de259b74` after Flutter CI #1540 green: Image edit availability now also requires an editor-supported JPG/JPEG/PNG format, preventing UI from enabling edit for unsupported formats such as GIF.

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
- a reusable canonical Image detail preview presentation component;
- canonical geometry refresh after managed byte edits;
- a safe canonical Image edit coordinator that refuses shared/ambiguous in-place edits and keeps geometry synchronized;
- advisory canonical Image edit availability aligned with both ownership and supported format.

Current WIP: #438 `feature/object-canonical-image-restore-preflight-245` adds `CanonicalImageEditService.canRestoreOriginal(...)` for presentation callers. It reuses the same canonical File lookup and exclusive managed-file ownership proof as edit/restore, and returns true only when `.bookmark_original` exists. Restore availability is intentionally independent of current edit-format support because an existing backup may still be restorable even when new edits for that extension are unsupported. Flutter CI #1545 found one Object-owned analyzer lint (`unawaited_return_in_try_block`) in the new preflight; head `63672058bb9ea3ab81c2a1c2b110a7f6f9b90f65` fixes it with an awaited backup lookup, and replacement CI #1548 is running.

Direct editor UI is still intentionally not exposed. Managed files may be shared by another Image, another workspace, or a legacy Photo consumer. #432 enforces fail-closed ownership before mutation; copy-on-edit remains deferred until a concrete product need justifies ownership transfer semantics. `CoreObjectBridge` remains the Photo compatibility mapping boundary and canonical Relation APIs remain unchanged.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Finish #438 replacement CI #1548 and merge only after green checks and a latest-main mergeability/non-overlap check.
2. Use the #432/#434/#436/#438 coordinator from a patch-sized Image detail/editor affordance once a safe insertion seam is available; edit/restore actions must still call `CanonicalImageEditService` and recheck safety immediately before mutation.
3. Wire #416's reusable canonical Image preview into `ObjectInspectorPage` only through a patch-sized Object-lane change after rechecking live open-PR ownership; do not reconstruct the large shared host through whole-file replacement.
4. Continue #245 canonical Bookmark Image write/edit UX only after deciding how legacy `bookmark_photos` authority is retired or write-through is handled; canonical-only writes are unsafe while compatibility sync can overwrite them.
5. Continue #249 with a patch-sized Stage1 List host slice when a hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
6. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
7. Continue #155 legacy presentation convergence only where a canonical replacement is already proven. Direct legacy URL reads that remain in shared hotspots or compatibility/query/import/export flows must not be removed merely for caller-count reduction.
8. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. #413 preserves canonical Relation-safe Object deletion ordering and adds only Object-owned filesystem cleanup afterward. #418 is coverage of existing canonical Bookmark Image Relations/backlinks. #423 adds a pre-delete Object-owned compatibility guard in the generic Images adapter but does not alter Relation persistence/lifecycle; allowed deletions still delegate to `RelationMutationService.deleteObject(...)`. #430 added Relation regression coverage for blocked Image deletion without changing production semantics. #432/#434/#436/#438 are Object-owned Image file/edit boundaries and do not introduce Relation writes.

### Refactor
Open Refactor PR #439 owns `notion_bookmark_card.dart` plus resolver-composition tests/handoff only; it does not overlap `canonical_image_edit_service.dart` or the #438 focused restore-preflight test. Always recheck open PR ownership before editing shared hosts/resolvers and do not absorb #225 cleanup into Object product PRs.

## Validation in this run
- Re-read latest `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, `docs/AI_PROGRESS_OBJECT.md`, current main, open PRs and CI before production edits.
- Confirmed #438 remained mergeable against its current base and did not overlap open Refactor #439.
- Inspected Flutter CI #1545 logs: dependency setup and Drift generation succeeded; Analyze failed only on `lib/services/canonical_image_edit_service.dart:128` with `unawaited_return_in_try_block`; Test was skipped because Analyze failed.
- Fixed the Object-owned analyzer issue by awaiting `imageEdit.hasBackup(editablePath)` inside the existing try/catch so asynchronous backup lookup errors remain covered by the intended preflight boundary.
- Replacement head is `63672058bb9ea3ab81c2a1c2b110a7f6f9b90f65`; Flutter CI #1548 is running.
- Re-audited remaining `bookmark.url` callers for #155. Direct reads still include shared UI hotspots plus compatibility/query/import/export/write-through paths; no unsafe caller-zero change was manufactured.
- No Relation representation, Photo mapping, Image bytes, schema, migration, shared UI host or copy-on-edit behavior changed in #438.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` and `object_inspector_page.dart` are shared conflict-prone hotspots; changes must be patch-sized and sequenced after live ownership checks.
- The current connector write path replaces complete existing files. Do not reconstruct large Stage1/Inspector/People hosts merely to make a small UI hunk change.
- Generic Images List still uses generic document-icon presentation rather than Image thumbnails; fixing it currently requires the large generic host unless a smaller dispatch seam is introduced safely.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation/file ownership state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.
- Image editing still has a shared-file hazard: an in-place edit can mutate another canonical Image or legacy Photo consumer even when Object metadata is separate. #432/#434/#436/#438 mitigate this by requiring exclusive managed-file ownership, supported editor format for new edits, backup existence for restore, and rechecking immediately before mutation; copy-on-edit is not yet defined.

## Stop / continuation condition
#436 is integrated and #438 is the current safe WIP. Continue #438 through replacement CI #1548 and merge only if green. After that, the next meaningful product step is a patch-sized Image detail/editor UI integration using the existing preview and safe edit coordinator. Shared-host preview/List/Stage1 changes remain intentionally deferred while the connector cannot apply hunk-sized edits to those large files. Do not manufacture parallel persistence/Relation abstractions merely to keep a run busy.
