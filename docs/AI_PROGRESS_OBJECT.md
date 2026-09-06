# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip and several List-readability slices are merged, Bookmark fixed/masonry and Stage1 host spacing remain.
- #245 — legacy Photos -> canonical Image Objects; managed import, deterministic reimport identity and Photo->Image bridge now exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation/Image parity is actionable.

Completed/closed during current convergence:
- #247 — Bookmark opening-mode parity; #344 merged and user validated real center-peek behavior.
- #149 — shared deterministic six-dot Property handle; #348 converged Bookmark host and user validated real-host alignment.
- #252 — Notion-like Property-add UX; shared popover, generic Table/detail, `PersonRoleProperties`, and `BookmarkReorderableProperties` are converged through #346/#349/#350/#366.
- #156 — generic fixed/masonry Gallery support is complete/closed.

## Current merged state — 2026-09-06
Latest main after this run: `cd5aae6f726028363306c4a9449bc1a3a6f10bdb` after Object #382.

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
- shared anchored `PropertyAddPopover` is merged (#346);
- generic Table and side-detail use the shared anchored add flow (#349);
- both Bookmark person-role add surfaces reuse the shared popover (#350/#366);
- Bookmark List metadata is split into description, compact secondary metadata and semantic-chip rows (#352/#370);
- Bookmark List semantic chips are width-bounded and long labels ellipsize (#354);
- Bookmark List URL metadata no longer directly reads legacy `bookmark.url` (#360);
- generic Image Gallery file resolution honors profile-relative managed paths (#375);
- legacy Photo mirrors reuse the canonical `ImageObjectService.ensureDefinition()` Image schema (#378);
- stable Image file identity prevents one managed file from fanning out into duplicate Image Objects across provenance changes (#379);
- legacy Photo promotion reuses existing canonical Images and preserves native Image ownership (#380);
- Weblink preview ingestion reuses canonical-equivalent Image source URLs before download/copy (#381);
- canonical Image import/reimport reuses byte-identical managed files deterministically while legacy/default Photo import keeps independent-copy semantics (#382).

## Checkpoints completed in this run
### #381 — canonical Image source lookup before Weblink preview download
Merged as `25c9618c8a957aff771fd3c864be15a57e6ba339` after Flutter CI #1403 green.

- `ImageObjectService.findBySourceUrl(...)` is the shared read-only source-identity lookup.
- `WeblinkPreviewImagePipeline` checks canonical/equivalent source identity before downloading preview media.
- older non-canonical provenance variants can reuse the existing Image Object without creating an orphan managed copy first.
- canonical Representative Image Relation mutation/verification remains unchanged.

### #382 — deterministic canonical Image reimport
Merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb` after Flutter CI #1404 green.

- canonical Image import opts into byte-identical managed-file reuse;
- comparison is deterministic and bounded by file size + 64 KiB chunks;
- rollback removes only newly copied files and never deletes a pre-existing reused managed file;
- default/legacy `PhotoStorageService` behavior remains independent copies, preserving live legacy Photo unique-path expectations;
- regression coverage proves repeated canonical import reuses both one managed file and one Image Object.

## #245 status after #379–#382
Phase 1 duplicate/reimport behavior is now deterministic for canonical managed Image import, and Phase 2 promotion has stronger canonical file-identity reuse. Do not build a second Photo->Image bridge: `CoreObjectBridge` remains the compatibility mapping boundary.

Remaining #245 work is product-semantic convergence rather than basic Image identity: Bookmark cover/multi-image semantics, generic Images parity with the useful legacy Photo workflow, Person profile image migration, path/Vault coordination where needed, and eventual legacy `写真` caller retirement. Any new Bookmark -> Image or Person -> Image Relation-producing workflow must use canonical Relation APIs and should request focused Relation-lane lifecycle coverage once the production write path exists.

## Exact next actions
1. Continue #249 with a patch-sized Stage1 List host slice: stable vertical/content padding or minimum height, title max-lines + ellipsis, and consistently aligned trailing actions. Recheck live hotspot ownership first.
2. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and the existing persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
3. Add/retain Bookmark real-host/widget regression proving fixed/masonry switching and independent per-View persistence while preserving sorting/filtering/opening semantics.
4. Continue #155 legacy presentation convergence only where a canonical replacement is already proven. A remaining read-only candidate is the related-Bookmark URL subtitle in `people_management_page.dart`; preserve legacy edit/import/export compatibility until caller-zero/migration policy is proven.
5. Reassess #245 Phase 1 acceptance as effectively covered by managed import + metadata + deterministic reimport, then choose the next product-semantic slice instead of another identity abstraction.
6. For Bookmark cover/multi-image migration, define the smallest canonical Image Relation product contract first and coordinate with Relation lane before introducing real Relation writes.
7. Defer broad #242 Vault work unless it becomes a direct dependency of the chosen Image path slice.

## Cross-lane coordination
### Relation
#381/#382 did not add or change Relation writes. Canonical Relation mutation/read/index/backlink behavior remains owned by Relation lane. New Bookmark -> Image or Person -> Image production writes are the trigger for focused lifecycle coverage; do not serialize Relation ids or create a parallel edge/index path.

### Refactor
Live open Refactor work at the end of this run includes #383 (`BookmarkObjectLinkReadStore` consolidation) and #385 (reverse-lookup resolver composition). Neither owns `bookmark_unified_stage1_page.dart`, but #383/#385 do touch Bookmark presentation/resolver boundaries, so recheck ownership before #155 resolver work. Refactor owns behavior-preserving deletion/extraction only after Object parity is proven.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; future #249 changes must be patch-sized and sequenced after live ownership checks;
- current GitHub write tooling for existing files replaces complete file contents rather than applying a local hunk, so reconstructing the large Stage1 host solely to change a few lines would violate the repository's patch-sized safety policy;
- `people_management_page.dart` is also a #245-listed migration hotspot; avoid a whole-file reconstruction for the remaining direct URL presentation line;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- Gallery parity must reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant;
- changing global legacy Photo storage semantics remains unsafe while the legacy Photo subsystem is live; #382 intentionally opted canonical Image import in without changing the default.

## Validation checkpoint
- #341/#344/#346/#348/#349/#350/#352/#354/#360/#366/#370/#371/#375/#378/#379/#380 are merged from prior checkpoints.
- #381 Flutter CI #1403 passed; squash merged as `25c9618c8a957aff771fd3c864be15a57e6ba339`.
- #382 Analyze and full Test passed in Flutter CI #1404; squash merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb`.
- #149/#247 real-host behavior was validated by the user and both issues are closed.
- #252 is closed after #366 converged the remaining reorderable person-role add path.

## Stop / continuation condition
This run merged the two safe Image identity/import slices that were already under CI and refreshed durable issue/handoff state. The next meaningful #249/#155 production changes are small logically but sit inside large shared hotspot files; with the current connector exposing whole-file replacement rather than safe hunk editing, reconstructing those hosts would be an avoidable conflict/regression risk and conflicts with `AGENTS.md` patch-sized guidance. Resume from #249 List/Gallery parity once a patch-capable edit path is available or another file-disjoint Object slice becomes actionable; do not manufacture an abstraction merely to keep changing code.
