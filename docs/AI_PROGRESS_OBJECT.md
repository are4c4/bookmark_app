# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #245 — legacy Photos -> canonical Image Objects and Image product-semantic convergence.
- #249 — Bookmark Gallery/List parity; List readability and fixed/masonry Stage1 host wiring remain.
- #242 — Vault folders remain lower priority while presentation/Image parity is actionable.

Completed/closed for current implementation scope: #247 Bookmark opening modes, #149 Property handle, #252 Property-add UX, #156 generic fixed/masonry Gallery, #166 aliases.

## Current merged state — 2026-09-07
Latest main observed in this run: `0a9f50704b63705c662f26bfb4119364c6801ca8` after Refactor #458. #458 only removed the caller-zero `ObjectGroupMode` declaration and did not touch the active Image files or shared Object hotspots.

Recent Object checkpoints relevant to current Image work:
- #416 merged: reusable canonical Image detail preview resolves managed media through `ImageVisualResolver`, uses persisted geometry/profile-relative paths, and fails safely for missing files.
- #423 merged: generic Image deletion is blocked while legacy Photo compatibility still owns/maps the Image, preventing delete/re-promote loops.
- #426 merged: `ImageObjectService.updateManagedGeometry(...)` refreshes persisted dimensions after managed byte edits.
- #432 merged: `CanonicalImageEditService` coordinates safe edit/restore operations, requires exclusive managed-file ownership, refreshes geometry, and rolls bytes back if metadata persistence fails.
- #434 merged: `canEdit(...)` exposes the same conservative ownership check to presentation callers.
- #436 merged: edit availability also requires an editor-supported JPG/JPEG/PNG format.
- #438 merged as `5724bdbf0cb3b8657548721c4c19d93d29076477`: `canRestoreOriginal(...)` exposes safe backup availability independently of current edit-format support.
- #442 merged as `340215ef530d00c577eb2fe3e5fca501d646773b`: `ObjectImageEditActions` provides rotate-left/right, horizontal flip and restore-original affordances behind `CanonicalImageEditService`.
- #447 merged as `5aacb98af79cb5387aa09b2abf2dd3f04f8da722`: `ObjectImageDetailPreview` can explicitly refresh same-path managed image bytes by re-resolving the visual and evicting the corresponding `FileImage` cache entry.

Broader merged product state remains:
- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live;
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated;
- Bookmark canonical URL and visual presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata;
- Bookmark opening modes use the shared presentation host;
- Bookmark Property rows/add flows are converged;
- legacy Bookmark photo attachments mirror through canonical Bookmark `Images` multi-Relation;
- legacy Bookmark `is_cover` mirrors through canonical Bookmark `Cover Image` single Relation;
- canonical Bookmark cover presentation reads `Cover Image` before legacy explicit-cover fallback;
- canonical Image reimport and Photo promotion use deterministic Image/file identity while preserving legacy compatibility semantics.

## Current WIP / product position
PR #457 `Compose canonical Image detail preview and edit actions` is the current Object-lane production slice. It is a clean two-file seam built on latest Image main after #447 and does not edit `ObjectInspectorPage` itself:
- new `ObjectImageDetailPanel` composes #416/#447 preview with #442 safe edit actions;
- successful edit/restore increments a private preview refresh token so same-path byte changes repaint;
- optional `onChanged` lets the future detail host reload persisted geometry without learning file-cache details;
- no Relation, Photo mapping, schema, file-ownership policy, or shared hotspot changes.

Flutter CI #1588 for #457 passed maintainability checks and Analyze, and 716 tests passed. The only failure was the new panel regression timing out after 10 minutes. The initial test redundantly exercised real file-byte editing/geometry persistence even though that behavior is already covered by `CanonicalImageEditService` tests. Commit `67ce96a6e6c6c2591ee569d92c5de3e00c8e57c8` narrows the panel regression to the panel-owned contract: safe action dispatch -> host notification -> refresh-token-driven same-path preview cache eviction. Production code is unchanged by this fix. Flutter CI #1593 is the current rerun and was still in progress when this handoff was written.

Refactor #458 is merged and has no overlap with #457 Image files.

The current GitHub connector can replace complete existing files but does not provide a hunk-sized patch write. `object_inspector_page.dart` and `bookmark_unified_stage1_page.dart` are shared, conflict-prone hotspots, so do not reconstruct either large host merely to insert a few lines. #457 deliberately creates a naturally smaller Image-detail seam so the eventual Inspector integration can remain patch-sized.

Person profile Image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Recheck live #457 head/CI and current main/open-PR ownership.
2. If Flutter CI #1593 is green, squash-merge #457. If it fails, inspect the exact failing test/log before changing production semantics; #1588 already established that Analyze and all other 716 tests were healthy.
3. After #457 merges, wire `ObjectImageDetailPanel` into the canonical Image branch of `ObjectInspectorPage` only through a patch-sized change. Route edit errors into the existing detail-host error affordance and use `onChanged` to reload persisted detail/geometry.
4. Keep edit/restore mutations exclusively behind `CanonicalImageEditService`; do not pass raw file paths from UI and do not bypass the immediate ownership recheck.
5. Continue #245 Bookmark Image write/edit UX only after legacy `bookmark_photos` authority/write-through semantics are explicit; canonical-only writes remain unsafe while compatibility sync can overwrite them.
6. Continue #249 Stage1 List polish through a patch-sized host change: stable row padding/minimum height, bounded title lines with ellipsis, and stable trailing-action alignment. Multi-Person chip rendering is already covered by current regressions.
7. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
8. Continue #155 legacy presentation convergence only where a canonical replacement is already proven. Do not remove remaining legacy URL/thumbnail reads from query/import/export/shared-host compatibility paths merely for caller-count reduction.
9. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. Current Image edit/detail work is Object-owned filesystem/presentation behavior and creates no new Relation producer. Bookmark `Images` and `Cover Image` continue to use canonical Relation APIs. Resume Relation implementation only if a new production Image/Bookmark workflow creates or retargets Relations or a concrete lifecycle regression appears.

### Refactor
#458 is merged deletion-only caller-zero cleanup in `object_group.dart` and has no overlap with #457. Always recheck live ownership before editing shared hosts/resolvers; Object product replacement must establish parity before Refactor removes compatibility paths.

## Validation in this run
- Re-read latest `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, `docs/AI_PROGRESS_OBJECT.md`, #155/#245/#249, closed priority checks #247/#149/#252, live open PRs, current main and CI before edits.
- Confirmed #447 is merged and main subsequently advanced through Refactor handoff #456 and caller-zero cleanup #458 without touching active Image files.
- Audited #457 as a clean two-file Image-detail composition seam and confirmed it did not claim `ObjectInspectorPage` or Stage1.
- Inspected Flutter CI #1588 job logs: Analyze succeeded, 716 tests passed, and only `object_image_detail_panel_test.dart` timed out after 10 minutes.
- Replaced the redundant real-file integration inside that panel regression with a fake `CanonicalImageEditService`, preserving the important composition checks while leaving byte/geometry behavior to the already-existing coordinator tests. Fix commit: `67ce96a6e6c6c2591ee569d92c5de3e00c8e57c8`.
- Updated #457 description to record the timeout diagnosis and test-scope correction. Flutter CI #1593 started for the corrected head.
- Re-audited #249: one-Person-per-chip behavior is already covered; remaining work is Stage1 List density/alignment and Gallery mode parity, both requiring a patch-sized shared-host change.
- No Relation representation, Photo mapping, schema, migration, copy-on-edit policy, or large shared UI host changed in this run.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` and `object_inspector_page.dart` are shared hotspots; changes must be patch-sized and sequenced after live ownership checks.
- The current connector write path replaces complete existing files. Do not reconstruct large Stage1/Inspector/People hosts merely to make a small UI hunk change.
- Byte edits preserve the managed file path; Image detail wiring must retain #447/#457 explicit refresh behavior so stale same-path image state is not shown.
- Generic Images List still uses generic document-icon presentation rather than Image thumbnails; fixing it currently requires a large generic host unless a smaller dispatch seam is introduced safely.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation/file ownership state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.

## Stop / continuation condition
#457 is the current safe seam. Process its corrected CI first. Once merged, the next highest-value Object product step is patch-sized `ObjectInspectorPage` wiring of `ObjectImageDetailPanel`, followed by #249 Stage1 List/Gallery parity. If only whole-file replacement is available for those large hosts, do not manufacture a broad rewrite or parallel persistence/Relation abstraction merely to keep a run busy.
