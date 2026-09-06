# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; List readability slices are merged, Bookmark fixed/masonry and Stage1 host spacing remain.
- #245 — legacy Photos -> canonical Image Objects; managed import, deterministic reimport identity, Photo->Image promotion and canonical Bookmark cover/image Relations exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation/Image parity is actionable.

Completed/closed during current convergence:
- #247 — Bookmark opening-mode parity.
- #149 — shared deterministic six-dot Property handle.
- #252 — Notion-like Property-add UX.
- #156 — generic fixed/masonry Gallery support.

## Current merged state — 2026-09-06
Latest Object product commit observed in this run: `720c5781b181f92ca4c0a06bb491a2dced052984` from #396. Always recheck live `main` before editing.

Key merged state:
- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live;
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated;
- Bookmark canonical URL and visual presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata;
- Bookmark opening modes use the shared presentation host;
- Bookmark Property rows/add flows are converged;
- Bookmark List metadata hierarchy and bounded chips are integrated;
- generic Image Gallery resolves profile-relative managed paths;
- legacy Photo mirrors reuse the canonical Image schema;
- stable Image identity prevents one managed file from fanning out into duplicate Images;
- legacy Photo promotion reuses existing canonical Images and preserves native Image ownership;
- canonical Image reimport reuses byte-identical managed files deterministically while legacy/default Photo import keeps independent-copy semantics;
- legacy Bookmark photo attachments mirror through canonical Bookmark `Images` multi-Relation;
- legacy Bookmark `is_cover` mirrors through canonical Bookmark `Cover Image` single Relation (#387);
- canonical Bookmark cover presentation now reads the `Cover Image` Relation before legacy explicit-cover fallback (#391);
- Refactor #383 and #395 have merged, so the resolver ownership conflict previously blocking canonical cover presentation is cleared;
- #396 now prevents first-time Photo -> Image promotion from creating a broken canonical Image when a filesystem-resolvable legacy Photo file is missing. Missing media leaves the legacy Photo untouched and retries naturally after the file reappears; unrooted relative paths remain compatibility identities.

## Latest Object checkpoint — #396
Merged as `720c5781b181f92ca4c0a06bb491a2dced052984` after Flutter CI Analyze/Test passed.

Behavior:
- existing stable `photo_object_links` mappings remain authoritative;
- empty paths fail closed;
- absolute paths are checked for existence before first promotion;
- relative paths are checked only when a profile/Vault root makes them resolvable;
- unrooted relative paths are treated as logical compatibility identities rather than process-working-directory paths;
- missing resolvable media creates no Image and no mapping, but does not mutate/delete the legacy Photo row;
- later sync retries promotion after media returns;
- stored Image File identity is not rewritten by the existence gate.

No Relation persistence/schema migration/file deletion behavior changed in #396.

## In-flight Object work
### #394 — preserve shared canonical Image files during legacy Photo deletion
Branch: `feature/object-photo-shared-file-delete-245`
Head observed: `f9ca5511cbc46c11ce0b82170f770a34791b4a5e`

Purpose:
- `BookmarkRepository.deletePhoto()` currently deletes the Photo row and then unconditionally removes the managed file;
- after Photo -> Image promotion, a native/shared canonical Image can independently own the same file;
- #394 adds a read-only ownership policy that preserves the file when canonical ownership is native/shared/ambiguous, while retaining legacy-only file cleanup.

Validation at this checkpoint:
- CI is still running; latest observed stage was Analyze after Drift generation.
- Recheck current-main mergeability before merging. #396 advanced `main` after #394 was opened; if GitHub reports a conflict, refresh/rebuild #394 rather than force-merging.

## #245 status
Phase 1 canonical managed Image creation/import and deterministic duplicate/reimport behavior are substantially covered.

Phase 2 Photo -> Image promotion now includes:
- stable mapping;
- canonical definition reuse;
- exact-file/native Image reuse;
- native-Image survival semantics;
- profile-relative presentation;
- safe skip/retry for resolvable missing media (#396).

Phase 3 Bookmark image semantics now includes:
- canonical `Images` multi-Relation;
- canonical `Cover Image` single Relation;
- canonical cover presentation read before legacy fallback (#391).

Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary. Do not bypass canonical Relation APIs. Preserve legacy explicit-cover presentation until real-host parity is proven and canonical write/edit UX exists.

Person profile image migration remains deferred because current People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object bridge/product contract is established.

## Exact next actions
1. Finish #394 only after CI green and current-main mergeability are confirmed. If stale/conflicting, rebuild the focused deletion-safety diff on latest main.
2. Recheck Relation #386 / any follow-up coverage for canonical `Cover Image` lifecycle; Object lane must not duplicate Relation correctness implementation.
3. Continue #249 with a patch-sized Stage1 List host slice when a safe hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
4. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
5. Continue #155 legacy presentation convergence only where a canonical replacement is already proven.
6. Continue #245 product-semantic Image convergence after #394: canonical Bookmark Image write/edit UX and generic Images parity before hiding legacy `写真`.
7. Defer Person profile Image migration and broad #242 Vault work until prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
Canonical Relation behavior remains mature. #387 is a genuine Bookmark -> Image Relation-producing workflow; Relation lane owns lifecycle coverage for value/edge/backlink/cardinality/idempotency/retarget/detach/delete safety. Object lane owns the Bookmark/Image product contract and bridge only.

### Refactor
#383 and #395 are merged. Open Refactor #397 is tests-only architecture guarding around direct Bookmark resolver construction and does not own Object production files used by #394/#396. Recheck open PR ownership before editing any shared resolver or Stage1 hotspot.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; future #249 changes must be patch-sized and sequenced after live ownership checks;
- current GitHub write tooling replaces complete existing file contents rather than applying a local hunk, so reconstructing large Stage1/People hosts solely for a few-line UI change remains unsafe;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant;
- canonical cover read migration must preserve explicit user-cover precedence and safe legacy fallback until parity is proven;
- changing global legacy Photo storage semantics remains unsafe while the legacy Photo subsystem is live;
- deleting a legacy Photo file is now known to require canonical Image ownership awareness; #394 is the active safety slice.

## Validation checkpoint
- #381 Flutter CI #1403 passed and merged.
- #382 Flutter CI #1404 passed and merged.
- #387 Flutter CI #1414 passed and merged.
- #391 canonical Bookmark Cover Image presentation read is merged.
- #396 Flutter CI Analyze/Test passed and merged as `720c5781b181f92ca4c0a06bb491a2dced052984`.
- #394 remains open/pending CI at this checkpoint.
- #149/#247 real-host behavior was validated by the user and both issues are closed.
- #252 is closed after the remaining reorderable person-role add path converged.

## Stop / continuation condition
Continue with #394 CI/refresh/integration first. If #394 cannot be safely refreshed within the current run, do not force it. #249 Stage1 changes remain logically small but unsafe to reconstruct wholesale through the current connector; use a hunk-capable path when available. Prefer another file-disjoint #155/#245 slice over manufacturing a parallel abstraction.
