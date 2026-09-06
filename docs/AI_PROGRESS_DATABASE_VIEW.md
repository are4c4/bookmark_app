# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Verify current open PR ownership before touching shared hosts.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created by configuration/templates rather than new management pages.

## Primary active issues
- #490 — templates instantiate user-owned ObjectTypes/Databases/Views.
- #491 — first-class Relation Property authoring and inline target creation UX.
- #492 — generic Gallery cover/media source from Object Relations.
- #493 — schema-evolution UX side; coordinate integrity-sensitive changes with Relation/Data Integrity lane.
- #249 — remaining Bookmark presentation parity only where it is a generic Database/View contract.
- #56 / #484 — umbrella product architecture.

## Current checkpoint — 2026-09-07
Latest verified main during this refresh: `a9823c705b731c61769b9ad056e92440e160a4e2` (main is moving frequently because all seven lanes are active).

No open Lane C PR remained when this handoff was refreshed. Current unrelated open PRs include Relation #577, Primitive #569, Search #575/#578, Storage #574/#576/#580, Refactor #579, and Object #550; none claims `generic_database_page.dart` broadly at this checkpoint, but ownership must be rechecked immediately before any hotspot edit.

### Integrated #490 template foundation
- PR #516 — generic user-owned template instantiation through canonical Object/Relation/View APIs.
- Template instances record only origin template key/version; later app updates do not silently rewrite customized user-owned schema.
- Relation template Properties resolve stable primitive system keys only at instantiation time and persist canonical workspace Property ids afterwards.
- Default Views are created through the generic `DatabaseViewStore` contract.
- PR #526 — added `Plant` as an unrelated architecture-success template using Image/Tag Relations plus ordinary Date/Text Properties and a generic Gallery View; fixed the template picker to scroll as template count grows.
- PR #563 — template Views can reference a template-local Relation Property and persist the ordinary `galleryCoverSource` setting after the created stable Property id is known. `Plant` now explicitly uses its `写真` Image Relation as Gallery cover source.
- Invalid or ambiguous template-local cover references fail transactionally instead of leaving partially configured domains.

Remaining #490 work:
- add a more representative domain such as Paper/Bookmark using Weblink/Image/File/Tag once primitive availability/bootstrap contracts are verified;
- prove empty custom ObjectType creation remains a first-class path;
- continue moving domain defaults into generic configuration rather than dedicated page code.

### Integrated #491 Relation Property authoring
- PR #515 — compact Property-add popover supports searchable Relation target ObjectType selection, built-in/custom distinction, and explicit single/multi cardinality.
- PR #538 — `DatabaseViewPropertyAuthoringService` routes ordinary Properties through `ObjectStore.createProperty` and Relations through canonical `ObjectStore.createRelationProperty`; it also exposes target ObjectTypes with system/custom kind.
- PR #552 — read-only Relation target quick-create policy classifies safe creation affordances:
  - custom ObjectType -> normal generic Object create;
  - Tag -> canonical Tag creation path;
  - Weblink -> URL-based canonical creation/enrichment;
  - Image -> managed Image import;
  - File -> managed File import;
  - unknown/internal system ObjectType, missing target, or cross-workspace target -> no quick-create.
- PR #567 — existing user-owned Relation Property target/cardinality editing now follows `RelationSchemaEvolutionService.inspectChange -> impact confirmation -> explicit multi-to-single choices -> updateRelationSchema`; UI never writes Relation config directly.

Remaining #491 work:
- wire the compact Property-add flow into the real generic Database host without reconstructing `generic_database_page.dart`;
- wire quick-create affordances into the Relation value picker using existing primitive/native creation services;
- Tag quick-create should reuse existing Tag creation plus `TagObjectBridge` synchronization, not introduce a second Tag writer;
- Weblink/Image/File quick-create must continue to reject title-only generic creation.

### Integrated #492 generic Gallery cover source
- PR #507 — per-View `galleryCoverSource` contract and schema-derived cover source discovery.
- PR #524 — fail-closed resolver from source Object + selected Relation Property to canonical Image/Weblink target; multi Relation selection is deterministic by persisted Relation position and no read path repairs Relation state.
- PR #542 — shared Gallery cover media dispatcher routes canonical Image targets to Image Gallery media and Weblink targets to `WeblinkGalleryMedia`; configured-but-missing media gets stable fixed/masonry fallback geometry.
- PR #556 — distinguishes an unconfigured View from explicit `none`; legacy system Image/Weblink Galleries retain historical automatic media behavior while custom ObjectTypes require explicit configuration.
- PR #563 — user-owned templates can persist the same generic Gallery cover contract using generated Relation Property ids.
- Lane B audited the Gallery compatibility/read path and reported no Relation integrity blocker.

Remaining #492 work:
- patch-size host wiring so fixed and masonry real generic Gallery cards consume `DatabaseViewGalleryCoverCompatibilityService` + shared cover dispatcher;
- expose discovered cover choices through the real toolbar host;
- preserve existing Bookmark compatibility while removing domain-specific Gallery assumptions only after parity is proven.

### Integrated #493 schema UX
- PR #520 — Relation schema-change impact confirmation dialog with explicit per-source choices for ambiguous multi -> single changes.
- PR #530 — `DatabaseViewPropertySchemaService` preserves stable Property identity on rename and performs read-only delete impact inspection across stored Object values plus View visible/order/filter/sort/group/Gallery-cover references.
- PR #547 — Property delete impact dialog lists stored-value/View impact and fail-closes destructive confirmation whenever data or View configuration would be lost/broken; it intentionally performs no deletion or cleanup.
- PR #567 — existing Relation Property schema editing is connected to Lane B's canonical transactional evolution service.

Lane B contract consumed by C:
- Relation state/index/bidirectional metadata must be healthy before mutation;
- every existing target is revalidated before target change;
- multi -> single requires explicit selection when multiple targets exist;
- single -> multi preserves existing values without unrelated Relation rewrites;
- apply re-validates transactionally and fails closed;
- bidirectional target retargeting remains blocked until a paired migration contract exists.

Remaining #493 work:
- safe Property archive/delete execution semantics; current UI correctly blocks destructive deletion when impact exists, and `generic_properties` has no archive state yet;
- explicit compatible Value-type conversion contract and impact UX;
- incompatible conversions must require an explicit migration or clear-values decision and rollback on failure;
- real-host wiring for rename/delete/Relation schema edit actions.

## Validation
All production slices listed above were validated by repository Flutter CI before merge. Notable successful runs in this implementation sequence include:
- #530 run 1768;
- #538 run 1776;
- #542 run 1781;
- #526 rerun 1796 after fixing template-picker overflow;
- #547 run 1803;
- #556 run 1821;
- #563 run 1830;
- #567 run 1841.

The connector execution path does not provide a local Flutter checkout, so GitHub Actions remains the executable validation source. CI failures should be diagnosed from job logs rather than guessed.

## Shared hotspot status
`generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart`, `app_shell.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart` remain shared hotspots. The generic Database page is ~2100 LOC and should not be whole-file reconstructed just to land small host wiring. Prefer service/widget seams and a genuinely patch-sized edit after rechecking live PR ownership.

## Exact next actions
1. Recheck current main/open PR ownership before every host edit because main is moving rapidly.
2. Wire #491 compact Relation Property creation into the real generic Database Property-add host using `DatabaseViewPropertyAuthoringService` and `PropertyAddPopover`; keep the page diff patch-sized.
3. Wire #492 real Gallery toolbar/cards to schema-derived cover options, compatibility resolution, and the shared cover dispatcher for both fixed and masonry modes.
4. Wire #567 Relation Property schema editor and #547 delete-impact dialog into generic Property management actions without bypassing canonical Relation/schema services.
5. Implement #491 Relation value quick-create UI by dispatching the merged quick-create policy to existing canonical Tag/Weblink/Image/File/custom creation paths; do not add primitive writers in Lane C.
6. Continue #490 with a Paper/Bookmark-style template only after verifying Weblink/Image/File/Tag system ObjectTypes are reliably available at template-application time.
7. For #493 Value-type conversion, prefer an explicit inspect/plan/confirm/apply contract with transaction rollback; coordinate if integrity behavior expands beyond presentation/schema UX.

## Cross-lane dependencies / risks
- Relation/Data Integrity lane owns correctness of Relation mutation and destructive target/cardinality evolution; C only composes UX around its canonical APIs.
- Primitive lane owns Tag/Weblink/Image/File creation semantics. C may select/display their creation affordances but must delegate execution.
- File primitive exists, but content-aware Image/File routing is still active in Primitive PR #569; avoid inventing a competing import path.
- Refactor lane is actively narrowing `AppDatabase`; avoid adding new presentation dependencies on it.
- No destructive Property archive/delete migration is approved yet. Keep existing fail-closed behavior until a reversible storage contract exists.

## Stop reason
This handoff refresh itself is not a lane stop. Continue with the next safe independent acceptance slice. Stop only if the next necessary step is blocked by a shared-hotspot lease, an unresolved cross-lane primitive/integrity contract, a materially risky schema migration requiring product approval, external CI infrastructure with no independent work remaining, or the runtime/session limit.
