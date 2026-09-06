# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip and several List-readability slices are merged, Bookmark fixed/masonry and Stage1 host spacing remain.
- #245 — legacy Photos -> canonical Image Objects; managed import, deterministic reimport identity, Photo->Image promotion and canonical Bookmark cover/image Relations now exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation/Image parity is actionable.

Completed/closed during current convergence:
- #247 — Bookmark opening-mode parity; #344 merged and user validated real center-peek behavior.
- #149 — shared deterministic six-dot Property handle; #348 converged Bookmark host and user validated real-host alignment.
- #252 — Notion-like Property-add UX; shared popover, generic Table/detail, `PersonRoleProperties`, and `BookmarkReorderableProperties` are converged through #346/#349/#350/#366.
- #156 — generic fixed/masonry Gallery support is complete/closed.

## Current merged state — 2026-09-06
Latest product commit at this checkpoint: `5a3cab0847664f2e2a7579dfa6de801223b0d4d5` after Object #387. Repository/docs-only commits may advance independently; always recheck live `main`.

- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated, including fixed mode (#334);
- Weblink/Image daily-use defaults, enriched titles, site/favicon/content-type/published-date metadata and clickable URL Properties are integrated;
- direct Weblink creation performs fail-soft metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- Bookmark canonical visual presentation covers Notion card, reverse lookup, lifecycle and Stage1 List/Table (#294/#299/#296/#324);
- Bookmark canonical URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata (#317/#320/#322/#341/#360/#371);
- Bookmark Stage1 honors View opening mode through shared presentation host (#344), real-host validated;
- Bookmark Property rows use shared deterministic six-dot layout (#348), real-host validated;
- one semantic chip per Bookmark Person role assignment is merged (#301);
- Bookmark List metadata is split into description, compact secondary metadata and semantic-chip rows (#352/#370), with bounded semantic chips (#354);
- generic Image Gallery file resolution honors profile-relative managed paths (#375);
- legacy Photo mirrors reuse the canonical `ImageObjectService.ensureDefinition()` Image schema (#378);
- stable Image file identity prevents one managed file from fanning out into duplicate Image Objects across provenance changes (#379);
- legacy Photo promotion reuses existing canonical Images and preserves native Image ownership (#380);
- Weblink preview ingestion reuses canonical-equivalent Image source URLs before download/copy (#381);
- canonical Image import/reimport reuses byte-identical managed files deterministically while legacy/default Photo import keeps independent-copy semantics (#382);
- legacy Bookmark photo attachments mirror through the canonical Bookmark `Images` multi-Relation;
- legacy Bookmark `is_cover` now mirrors through additive canonical Bookmark `Cover Image` single Relation (#387).

## Checkpoints completed in the latest Object run
### #381 — canonical Image source lookup before Weblink preview download
Merged as `25c9618c8a957aff771fd3c864be15a57e6ba339` after Flutter CI #1403 green.

- `ImageObjectService.findBySourceUrl(...)` is the shared read-only source-identity lookup.
- `WeblinkPreviewImagePipeline` checks canonical/equivalent source identity before downloading preview media.
- older non-canonical provenance variants can reuse the existing Image Object without creating an orphan managed copy first.

### #382 — deterministic canonical Image reimport
Merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb` after Flutter CI #1404 green.

- canonical Image import opts into byte-identical managed-file reuse;
- comparison is deterministic and bounded by file size + 64 KiB chunks;
- rollback removes only newly copied files and never deletes a pre-existing reused managed file;
- default/legacy `PhotoStorageService` behavior remains independent copies.

### #387 — canonical Bookmark Cover Image Relation
Merged as `5a3cab0847664f2e2a7579dfa6de801223b0d4d5` after Flutter CI #1414 green.

- system Bookmark now has additive `Cover Image` single Relation targeting canonical Image alongside existing `Images` multi-Relation;
- `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` only through `RelationMutationService.setRelation(...)`;
- changing the legacy cover retargets the canonical single Relation; clearing the legacy cover detaches it without changing the multi-Image Relation;
- multiple legacy cover flags fail closed instead of selecting an arbitrary Image;
- a selected cover whose Photo has no stable Image link also fails closed;
- legacy Photo/Bookmark tables and existing Bookmark visual fallback remain intact during migration.

## #245 status after #387
Phase 1 canonical managed Image creation/import and deterministic duplicate/reimport behavior are substantially covered. Phase 2 Photo -> Image promotion has stable mapping, canonical definition reuse, exact-file reuse, native-Image survival and profile-relative presentation coverage. Phase 3 has now started: the existing Bookmark `Images` multi-Relation is joined by the canonical `Cover Image` single Relation.

Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary. Do not bypass canonical Relation APIs. The next migration step is read/presentation parity for `Cover Image`, then canonical write/edit UX, before legacy cover storage can be considered compatibility-only.

Person profile image migration remains intentionally deferred: current Person UX is still legacy `People.profilePhotoId`/Photo-oriented and no first-class Person Object bridge was found at this checkpoint. Do not invent a parallel Person Image model merely to advance #245.

## Exact next actions
1. Let Relation lane complete focused lifecycle coverage for the new #387 `Cover Image` single Relation: value/edge/backlink/cardinality, repeated-sync idempotency, retarget, detach and Relation-safe Image deletion. Relation #386 already covers the pre-existing Bookmark `Images` multi-Relation and has been notified of #387.
2. After Refactor #383 finishes owning `bookmark_visual_resolver.dart`, add read-only canonical Bookmark `Cover Image` resolution there with precedence `canonical Cover Image -> legacy explicit cover fallback -> Weblink Representative Image -> legacy remote thumbnail`. Do not repair Relation state from presentation.
3. Preserve the legacy explicit-cover read until canonical cover presentation has real-host/regression parity, then reduce it in a separate safe compatibility-retirement slice.
4. Continue #249 with a patch-sized Stage1 List host slice when a safe hunk-capable edit path is available: stable padding/minimum height, title max-lines + ellipsis, trailing alignment.
5. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
6. Continue #155 legacy presentation convergence only where a canonical replacement is already proven; avoid resolver files while #383/#385 own overlapping Refactor work.
7. Defer Person profile Image migration and broad #242 Vault work until their prerequisite Object/product contracts are established.

## Cross-lane coordination
### Relation
#387 is now a genuine new production Relation-producing workflow. Object lane owns the Bookmark/Image product contract and bridge; Relation lane owns focused correctness coverage for `Cover Image` lifecycle. No new Relation persistence implementation is required: reuse the existing mutation/read/index/backlink/audit/reconcile subsystem. A coordination comment was posted on Relation PR #386 after #387 merged.

### Refactor
Open Refactor work observed at this checkpoint includes #383 (`BookmarkObjectLinkReadStore` consolidation) and #385 (reverse-lookup resolver composition). #383 directly owns `bookmark_visual_resolver.dart`; do not create an overlapping Object PR there until it merges/closes. Rebuild intended resolver changes on the then-current `main` rather than force-merging stale ancestry.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; future #249 changes must be patch-sized and sequenced after live ownership checks;
- current GitHub write tooling replaces complete existing file contents rather than applying a local hunk, so reconstructing large Stage1/People hosts solely for a few-line UI change remains an avoidable conflict/regression risk;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant;
- canonical cover read migration must preserve explicit user-cover precedence and safe legacy fallback until parity is proven;
- changing global legacy Photo storage semantics remains unsafe while the legacy Photo subsystem is live; canonical Image import intentionally opts into dedupe without changing default Photo import behavior.

## Validation checkpoint
- #341/#344/#346/#348/#349/#350/#352/#354/#360/#366/#370/#371/#375/#378/#379/#380 are merged from prior checkpoints.
- #381 Flutter CI #1403 passed and merged as `25c9618c8a957aff771fd3c864be15a57e6ba339`.
- #382 Flutter CI #1404 passed and merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb`.
- #387 Flutter CI #1414 Analyze/Test passed and merged as `5a3cab0847664f2e2a7579dfa6de801223b0d4d5`.
- #149/#247 real-host behavior was validated by the user and both issues are closed.
- #252 is closed after #366 converged the remaining reorderable person-role add path.

## Stop / continuation condition
The current next safe Object implementation is sequenced behind active cross-lane ownership rather than blocked by product ambiguity: canonical cover presentation should wait for Refactor #383 to release `bookmark_visual_resolver.dart`, while Relation lane should cover #387 lifecycle independently. #249 Stage1/People host changes remain logically small but unsafe to reconstruct wholesale through the current connector. Continue immediately when either the resolver ownership clears or another file-disjoint Object slice becomes actionable; do not manufacture a parallel abstraction merely to keep changing code.
