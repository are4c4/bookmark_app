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
Latest main observed in this run: `340215ef530d00c577eb2fe3e5fca501d646773b` after Object #442.

Recent Object checkpoints relevant to current Image work:
- #416 merged: reusable canonical Image detail preview resolves managed media through `ImageVisualResolver`, uses persisted geometry/profile-relative paths, and fails safely for missing files.
- #423 merged: generic Image deletion is blocked while legacy Photo compatibility still owns/maps the Image, preventing delete/re-promote loops.
- #426 merged: `ImageObjectService.updateManagedGeometry(...)` refreshes persisted dimensions after managed byte edits.
- #432 merged: `CanonicalImageEditService` coordinates safe edit/restore operations, requires exclusive managed-file ownership, refreshes geometry, and rolls bytes back if metadata persistence fails.
- #434 merged: `canEdit(...)` exposes the same conservative ownership check to presentation callers.
- #436 merged: edit availability also requires an editor-supported JPG/JPEG/PNG format.
- #438 merged as `5724bdbf0cb3b8657548721c4c19d93d29076477`: `canRestoreOriginal(...)` exposes safe backup availability independently of current edit-format support.
- #442 merged as `340215ef530d00c577eb2fe3e5fca501d646773b` after Flutter CI #1555 green: `ObjectImageEditActions` provides rotate-left/right, horizontal flip and restore-original affordances. Availability and mutations remain behind `CanonicalImageEditService`; the widget does not receive a raw file path or call `ImageEditService` directly.

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
There is no unsafe direct Image editor exposure. The safe coordinator and action widget are now merged, but the real shared Object detail host still needs a small integration hunk that combines #416 preview with #442 edit actions for canonical Images only.

The current GitHub connector can replace complete existing files but does not provide a hunk-sized patch write. `object_inspector_page.dart` and `bookmark_unified_stage1_page.dart` are shared, conflict-prone hotspots, so do not reconstruct either large host merely to insert a few lines. Wait for a patch-sized edit path or a naturally smaller host seam.

Also account for presentation refresh when wiring edit actions: byte edits keep the same managed file path, so the host must make the Image preview refresh after successful rotate/flip/restore rather than assuming a path change will invalidate presentation state.

Person profile Image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Recheck live open PR ownership before touching any shared host.
2. Wire #416 `ObjectImageDetailPreview` + #442 `ObjectImageEditActions` into the canonical Image branch of `ObjectInspectorPage` only through a patch-sized change. On successful mutation, refresh/re-resolve the preview and surface failures through the existing detail-host error affordance.
3. Keep edit/restore mutations exclusively behind `CanonicalImageEditService`; do not pass raw file paths from UI and do not bypass the immediate ownership recheck.
4. Continue #245 Bookmark Image write/edit UX only after legacy `bookmark_photos` authority/write-through semantics are explicit; canonical-only writes remain unsafe while compatibility sync can overwrite them.
5. Continue #249 Stage1 List polish through a patch-sized host change: stable row padding/minimum height, bounded title lines with ellipsis, and stable trailing-action alignment.
6. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
7. Continue #155 legacy presentation convergence only where a canonical replacement is already proven. Do not remove remaining legacy URL/thumbnail reads from query/import/export/shared-host compatibility paths merely for caller-count reduction.
8. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. Current Image edit work is Object-owned filesystem/presentation behavior and creates no new Relation producer. Bookmark `Images` and `Cover Image` continue to use canonical Relation APIs. Resume Relation implementation only if a new production Image/Bookmark workflow creates or retargets Relations or a concrete lifecycle regression appears.

### Refactor
At the time of this run, open Refactor work was documentation/maintainability handoff and did not own the Image preview/edit widget files. Always recheck live PR ownership before editing shared hosts/resolvers; Object product replacement must establish parity before Refactor removes compatibility paths.

## Validation in this run
- Re-read latest `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, `docs/AI_PROGRESS_OBJECT.md`, live open PRs and latest main before edits.
- Rechecked #442 against latest main. It was one main commit behind, but its diff remained exactly two newly added files (`object_image_edit_actions.dart` and `object_image_edit_actions_test.dart`) with no overlap with the intervening main change.
- Confirmed Flutter CI #1555 completed successfully for #442.
- Squash-merged #442 as `340215ef530d00c577eb2fe3e5fca501d646773b`.
- Re-audited #249 and the current Image preview/editor seams. No safe reason was found to reconstruct `ObjectInspectorPage` or Stage1 wholesale through the connector's full-file replacement write path.
- No Relation representation, Photo mapping, schema, migration, copy-on-edit policy, or large shared UI host changed in this run.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` and `object_inspector_page.dart` are shared hotspots; changes must be patch-sized and sequenced after live ownership checks.
- The current connector write path replaces complete existing files. Do not reconstruct large Stage1/Inspector/People hosts merely to make a small UI hunk change.
- Byte edits preserve the managed file path; Image detail wiring must explicitly refresh presentation after successful edits/restores so stale same-path image state is not shown.
- Generic Images List still uses generic document-icon presentation rather than Image thumbnails; fixing it currently requires a large generic host unless a smaller dispatch seam is introduced safely.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation/file ownership state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.

## Stop / continuation condition
#442 is integrated. The next highest-value Object product step is the patch-sized canonical Image detail integration of #416 preview plus #442 actions, followed by #249 Stage1 List/Gallery parity. Both currently require editing shared hotspot hosts; do not manufacture a full-file rewrite or parallel persistence/Relation abstraction merely to keep a run busy. If a hunk-capable edit path becomes available, resume directly from the exact next actions above.
