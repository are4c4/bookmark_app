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
Always recheck live `main` before editing. During this run, `main` advanced concurrently; the refreshed #413 branch was created from `93db805cd7aa05d6cf3d6ea80c79e3aab225d0c1`.

Recent Object checkpoints:
- #394 merged as `1f26ec2b949fd5960ae719b47bdf0d5731ceee48`: legacy Photo deletion now preserves a managed file when a surviving canonical Image owns/shares it while retaining legacy-only cleanup.
- #396 merged as `720c5781b181f92ca4c0a06bb491a2dced052984`: first Photo -> Image promotion skips filesystem-resolvable missing media and retries naturally if the file returns.
- #409 merged in this run as `1024ef2cec5ffa30b9b5abaf60b9327b53021688` after Flutter CI #1472 green: canonical Image detail can edit Object title and the Image `Note` Value while managed `File`, provenance/geometry, aliases and Body remain protected; other system ObjectTypes remain read-only.

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

## In-flight Object work
### #413 — managed canonical Image file cleanup on generic Image deletion
Branch: `feature/object-image-managed-file-delete-245-refresh`
Head at handoff before documentation commit: `76fa1b455eb7d1c9da246c086ee8743cd04f2890`.

#413 supersedes closed/unmerged #402. #402 had become 13 commits behind main and conflicted in `generic_database_page_services.dart`; it was deliberately not force-merged. Its Flutter CI Analyze passed and every focused ownership-policy test passed, but the additional real-host widget test timed out after 10 minutes because the mounted GenericDatabasePage retained live Drift activity after the assertions.

The refreshed #413 was rebuilt from current main with the same four-file product/test surface and adds explicit widget-host unmount before database teardown.

Behavior:
- generic Image Object deletion still delegates canonical Object/Relation lifecycle to `RelationMutationService.deleteObject(...)`;
- an Object-owned read-only `ImageManagedFileDeletionPolicy` audits the Image `File` before deletion;
- physical deletion is permitted only inside active managed photo storage and only when no surviving legacy Photo or canonical Image resolves to the same physical file;
- external paths, symlink escapes, shared files, malformed/ambiguous state, missing audit tables, or audit failures preserve the file fail-closed;
- physical file and `.bookmark_original` cleanup happens only after successful canonical Object deletion and is best-effort afterward;
- no Relation storage/index/backlink semantics, schema migration, Vault move, or legacy Photo deletion behavior are changed.

Validation at this handoff:
- #402 Analyze green.
- #402 focused Image deletion policy tests all green: solely-owned cleanup, legacy Photo sharing, cross-workspace Image sharing, external path preservation, symlink escape preservation.
- #402 real-host test timed out only at process/test teardown after the deletion assertions path had progressed; #413 explicitly disposes the host.
- #413 Flutter CI #1481 is in progress; do not merge until Analyze/Test are green.

## #245 status
Canonical Image identity/import/reimport and Photo -> Image promotion safety are substantially covered. Current product-semantic work now includes:
- canonical Bookmark `Images` multi-Relation;
- canonical Bookmark `Cover Image` single Relation;
- canonical cover presentation before legacy fallback;
- user-editable canonical Image title + `Note` through the shared Object detail (#409);
- safe legacy Photo file deletion ownership (#394);
- pending generic Image deletion managed-file cleanup (#413).

Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary. Do not bypass canonical Relation APIs. Preserve legacy explicit-cover/Photo compatibility until real-host write/edit parity and migration policy are proven.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Recheck #413 Flutter CI #1481 and merge only when green and current-main mergeability remains safe. If main advances into a conflict again, refresh the focused four-file diff rather than force-merging.
2. After #413, continue #245 generic Images daily-use parity and canonical Bookmark Image write/edit UX without introducing new Relation persistence paths.
3. Continue #249 with a patch-sized Stage1 List host slice when a hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
4. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
5. Continue #155 legacy presentation convergence only where a canonical replacement is already proven.
6. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. Bookmark -> Image relation-producing workflows use canonical Relation APIs and lifecycle coverage belongs to the Relation lane. #409 and #413 do not introduce a new Relation representation or mutation path; #413 wraps the existing canonical Object deletion service only to perform Object-owned filesystem cleanup after successful deletion.

### Refactor
At this run, live Refactor PRs included #408 (focused Bookmark backlink read boundary) and #410 (Bookmark FTS projection deduplication). They did not own #409/#413 production files. Always recheck open PR ownership before editing shared hosts/resolvers. Do not absorb #225 cleanup into Object product PRs.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; #249 changes must be patch-sized and sequenced after live ownership checks.
- Connector writes replace complete existing files, so reconstructing large Stage1/People hosts for a few-line UI hunk remains unsafe.
- Legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven.
- Identity-sensitive Weblink/Image creation must never fall back to raw title-only creation.
- Ambiguous Relation state must fail closed; presentation/filesystem cleanup must not repair it.
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.
- Destructive filesystem cleanup must retain fail-closed ownership checks; leaking an orphan managed file is preferable to deleting a shared/external user file.

## Stop / continuation condition
First process #413 CI/integration. CI pending alone is not a stop condition: if another file-disjoint Object slice is clearly safe, continue it. Do not manufacture a parallel abstraction or reconstruct a large hotspot through whole-file replacement merely to keep a run busy.
