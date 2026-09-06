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
Latest main observed in this run: `442804c8c15c65fd66ed95ccbfde9d20172c48bf` after Object #416.

Recent Object checkpoints:
- #394 merged as `1f26ec2b949fd5960ae719b47bdf0d5731ceee48`: legacy Photo deletion preserves a managed file when a surviving canonical Image owns/shares it while retaining legacy-only cleanup.
- #396 merged as `720c5781b181f92ca4c0a06bb491a2dced052984`: first Photo -> Image promotion skips filesystem-resolvable missing media and retries naturally if the file returns.
- #409 merged as `1024ef2cec5ffa30b9b5abaf60b9327b53021688`: native canonical Image detail can edit Object title and Image `Note` while identity/provenance fields stay protected.
- #415 merged: legacy-owned mirrored Images with `Legacy Photo ID` stay read-only so compatibility sync cannot silently overwrite user edits.
- #413 merged after Flutter CI #1489 green: generic Image deletion keeps canonical `RelationMutationService.deleteObject(...)` first and then performs fail-closed best-effort managed-file cleanup only when ownership is unambiguous.
- #418 merged: test-only real-host coverage proves canonical Image backlinks already replace the legacy Photo reverse-lookup concept for Bookmark `Images` + `Cover Image` Relations.
- #416 merged in this run as `442804c8c15c65fd66ed95ccbfde9d20172c48bf` after Flutter CI #1498 green: reusable canonical Image detail preview presentation now resolves managed media through `ImageVisualResolver`, uses persisted geometry, resolves profile-relative paths, and fails visibly/safely for missing files.

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
- canonical Image backlinks covering the legacy Bookmark reverse-lookup concept;
- a reusable canonical Image detail preview presentation component.

The next product step is to wire the new #416 preview into the shared Object detail host in a small sequenced patch, then continue canonical Bookmark Image write/edit UX. Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary. Do not bypass canonical Relation APIs. Preserve legacy explicit-cover/Photo compatibility until real-host write/edit parity and migration policy are proven.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Wire #416's reusable canonical Image preview into `ObjectInspectorPage` with a patch-sized Object-lane change after rechecking live open-PR ownership; do not reconstruct the large shared host through whole-file replacement.
2. Continue #245 canonical Bookmark Image write/edit UX without introducing a new Relation persistence representation; any genuinely new Relation-producing workflow requires Relation-lane lifecycle coverage.
3. Continue #249 with a patch-sized Stage1 List host slice when a hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
4. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
5. Continue #155 legacy presentation convergence only where a canonical replacement is already proven.
6. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. #413 keeps canonical Relation-safe Object deletion ordering and adds only Object-owned filesystem cleanup afterward. #418 is tests-only coverage of existing canonical Bookmark Image Relations/backlinks. #416 is presentation-only and introduces no Relation mutation path. Current Relation PR #420 is handoff-only and does not own Object production files.

### Refactor
Live Refactor PR #419 currently owns Bookmark FTS projection cleanup and does not overlap #416/Image detail presentation. Always recheck open PR ownership before editing shared hosts/resolvers. Do not absorb #225 cleanup into Object product PRs.

## Validation in this run
- Re-read latest `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, and this Object handoff before acting.
- Rechecked open PR ownership: #420 Relation handoff-only, #419 Bookmark FTS refactor, #416 Object Image preview.
- Confirmed #413 was already merged and its Flutter CI #1489 completed successfully.
- Confirmed #416 was mergeable and Flutter CI #1498 completed successfully.
- Squash-merged #416 as `442804c8c15c65fd66ed95ccbfde9d20172c48bf`.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` and `object_inspector_page.dart` are shared conflict-prone hotspots; changes must be patch-sized and sequenced after live ownership checks.
- The current connector write path replaces complete existing files. Do not reconstruct large Stage1/Inspector/People hosts merely to make a small UI hunk change.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation/file ownership state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.

## Stop / continuation condition
#416 is integrated. The next highest-value step is the small `ObjectInspectorPage` integration of the reusable Image preview, but the available connector only supports whole-file replacement for existing files; reconstructing a large shared host for a small hunk would violate the repository's patch-sized shared-hotspot rule. Resume that exact integration when a hunk-capable edit path is available. Meanwhile #249 Stage1 work has the same tooling constraint. Do not manufacture a parallel abstraction or broaden into Relation/Refactor ownership merely to keep a run busy.
