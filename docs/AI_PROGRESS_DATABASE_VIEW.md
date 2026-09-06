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
All seven lanes are active and `main` moves frequently. Recheck live PR ownership immediately before touching a shared hotspot.

### #490 — user-owned domain templates
Integrated:
- #516 generic template instantiation through ordinary Object/Relation/View APIs.
- #526 Plant proves an unrelated domain can be a normal custom ObjectType with no dedicated management page.
- #563 template-local Relation Properties can configure the ordinary per-View `galleryCoverSource` contract transactionally.
- #592 provisions missing Tag/Weblink/Image/File primitive targets only through canonical ensure paths and adds a user-owned Paper template composed from those four primitives plus ordinary DOI/date/text Properties and generic Gallery/Table Views. CI run 1907 was green before merge.

Remaining:
- keep empty custom ObjectType creation a first-class user path;
- continue replacing domain-specific defaults with ordinary schema/View/template configuration rather than new domain pages.

### #491 — Relation Property authoring / inline target creation
Integrated:
- #515 compact Property-add UI: searchable Relation target ObjectTypes, built-in/custom distinction, explicit single/multi.
- #538 `DatabasePropertyAuthoringService`: ordinary Properties use `ObjectStore.createProperty`; Relations use canonical `ObjectStore.createRelationProperty`.
- #552 read-only `RelationTargetQuickCreatePolicy`: custom Object / Tag / URL Weblink / managed Image / managed File / unavailable.
- #567 existing Relation Property target/cardinality editing composes the transactional schema-evolution service and explicit impact/choice UX.
- #595 `RelationTargetQuickCreateAction`: presentation-only mode-specific quick-create affordance. Unavailable or missing canonical writer exposes no title-only fallback. Flutter CI run 1916 completed successfully before squash merge (`eaa18d4f`).

Remaining:
- patch-size real-host wiring of `DatabasePropertyAuthoringService` + `PropertyAddPopover` into the generic Database page;
- wire quick-create policy/action into the existing Relation value picker and delegate execution to canonical custom Object/Tag/Weblink/Image/File creation/import callbacks;
- keep Weblink/Image/File title-only creation impossible.

### #492 — generic Gallery cover source
Integrated:
- #507 per-View cover-source contract and schema-derived source discovery.
- #524 fail-closed Relation target resolver with deterministic persisted Relation order.
- #542 shared cover media dispatcher for canonical Image/Weblink targets and stable fixed/masonry fallback geometry.
- #556 unconfigured-system compatibility versus explicit `none`.
- #563 template cover configuration; #592 Paper exercises it on a fresh workspace.

Remaining:
- replace the real generic Gallery host's current unconditional Weblink media path with compatibility resolution + `DatabaseGalleryCoverMedia` for both fixed and masonry cards;
- expose schema-derived cover choices through the real Gallery toolbar;
- preserve Bookmark compatibility until generic parity is proven.

### #493 — safe schema-editing UX
Integrated:
- #520 Relation schema-change impact confirmation and explicit multi -> single choices.
- #530 stable-id rename and read-only Property delete impact inspection across stored values and View references.
- #547 destructive delete confirmation is blocked when data/View configuration would be lost.
- #567 Relation schema editor uses canonical transactional evolution.
- #568 bidirectional inverse-Property impact is surfaced and deletion remains fail-closed.

Remaining:
- reversible Property archive/delete execution semantics (no archive state exists yet);
- explicit Value-type conversion inspect/plan/confirm/apply contract with rollback;
- patch-size real-host action wiring for rename/delete/Relation schema editing.

## Validation this run
- #592: Flutter CI run 1907 completed successfully; PR merged.
- #595: Flutter CI run 1916 completed successfully; PR squash-merged as `eaa18d4fb37f0d56c065b31da89f85880087188c`.
- No local Flutter checkout is available through the connector execution path; GitHub Actions is the executable validation source.

## Shared hotspot / concurrency status
During this run, open-PR searches found no broad owner for `generic_database_page.dart`, `object_inspector_page.dart`, or `generic_database_page_services.dart`. Recheck immediately before any edit.

Shared hotspots include `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart`, `app_shell.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`. Do not reconstruct a whole hotspot for a small integration; use patch-sized edits after ownership verification.

## Exact next actions
1. Wire `DatabasePropertyAuthoringService` + `PropertyAddPopover` into the real generic Database Property-add host without direct Relation config writes.
2. Wire `RelationTargetQuickCreatePolicy` + `RelationTargetQuickCreateAction` into the real Relation value picker, delegating to canonical target creation/import services.
3. Wire `DatabaseViewGalleryCoverCompatibilityService` + `DatabaseGalleryCoverMedia` into fixed/masonry real Gallery cards, then expose source options in the toolbar.
4. Wire #567 and #547/#568 schema-edit/delete-impact actions into Property management UX without bypassing canonical schema/Relation services.
5. Continue #490 only through user-owned ObjectType/Property/Relation/Database/View configuration; no Paper/Plant/Bookmark-specific management pages.

## Cross-lane boundaries / risks
- Lane B owns Relation mutation/data-integrity and destructive target/cardinality correctness.
- Lane D owns Tag/Weblink/Image/File identity and canonical creation/import semantics; Lane C only presents/dispatches those actions.
- Lane E owns search/indexing; Lane F owns Vault/filesystem lifecycle.
- Refactor lane is reducing `AppDatabase` reach-through; Lane C must not add new direct presentation dependencies on it.
- No destructive Property archive/delete migration is approved; fail-closed behavior remains correct until a reversible storage contract exists.

## Stop reason for this run
Two independent non-hotspot product slices were completed and integrated (#592 and #595), stale docs PRs were retired, and this handoff was rebuilt from current `main`. The next high-value slices are real-host integrations in shared files; they should start from a fresh ownership check and a fresh branch rather than stacking a broad hotspot edit onto now-merged implementation branches.
