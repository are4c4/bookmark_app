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
Main is moving rapidly because all seven lanes are active, so recheck immediately before editing a shared hotspot.

### Integrated #490 template foundation
- #516 — generic user-owned template instantiation through ordinary Object/Relation/View APIs.
- Template instances persist origin key/version only; app updates do not silently reset user-customized schema.
- #526 — Plant template proves an unrelated domain can be created as a normal custom ObjectType without a Plant management page.
- #563 — template Views can resolve a template-local Relation Property to its created stable id and persist the ordinary `galleryCoverSource` contract transactionally.
- Plant uses its Image Relation as a generic Gallery cover source.
- #592 — primitive Relation targets are provisioned through canonical ensure paths on fresh workspaces, and Paper is now a user-owned template composed from Weblink/Image/File/Tag plus ordinary DOI/date/text Properties and generic Gallery/Table Views. Unknown primitive keys remain fail-closed. CI run 1907 completed successfully before merge.

Remaining #490 work:
- prove empty custom ObjectType creation remains a first-class path in real UX;
- continue moving domain defaults into ordinary user-owned configuration rather than dedicated pages;
- avoid adding Bookmark/Paper-specific persistence or management hosts.

### Integrated #491 Relation Property authoring
- #515 — compact Property-add popover supports searchable Relation target selection, built-in/custom distinction and explicit single/multi cardinality.
- #538 — `DatabasePropertyAuthoringService` routes ordinary Properties through `ObjectStore.createProperty` and Relation schema through canonical `ObjectStore.createRelationProperty`.
- #552 — `RelationTargetQuickCreatePolicy` classifies safe inline creation modes: custom Object, Tag, URL-based Weblink, managed Image, managed File, or unavailable.
- #567 — existing user-owned Relation Property target/cardinality editing uses inspect -> impact confirmation -> explicit choices -> transactional canonical schema update.

Open follow-up:
- #595 — adds a presentation-only `RelationTargetQuickCreateAction` that renders the mode-appropriate affordance and hides unavailable/missing-writer cases instead of falling back to title-only creation. It delegates every mutation to host-supplied canonical callbacks. Analyze is green; full test completion is still pending at this checkpoint.

Remaining #491 work:
- connect Property-add authoring to the real generic Database host through `DatabasePropertyAuthoringService` with a patch-sized page diff;
- connect quick-create actions to the existing Relation value picker and canonical Tag/Weblink/Image/File/custom creation services;
- keep Weblink/Image/File title-only creation impossible.

### Integrated #492 generic Gallery cover source
- #507 — per-View `galleryCoverSource` contract and schema-derived source discovery.
- #524 — fail-closed Relation cover target resolver with deterministic persisted Relation order.
- #542 — shared cover media dispatcher delegates Image/Weblink targets to canonical media widgets and preserves stable fixed/masonry fallback geometry.
- #556 — distinguishes never-configured Views from explicit `none`; system Image/Weblink collections keep historical defaults while custom ObjectTypes require explicit configuration.
- #563 — templates persist the same generic cover contract using generated Relation Property ids.
- #592 — Paper template exercises the same generic Image Relation cover configuration on a fresh workspace.

Remaining #492 work:
- patch-size real-host wiring so generic fixed/masonry Gallery cards consume compatibility resolution + shared cover dispatcher;
- expose schema-derived cover choices in the real Gallery toolbar;
- preserve Bookmark compatibility until generic parity is proven.

### Integrated #493 schema UX
- #520 — Relation schema-change impact confirmation with explicit choices for ambiguous multi -> single changes.
- #530 — stable-id Property rename plus read-only delete-impact inspection across stored values and View references.
- #547 — destructive Property delete confirmation is disabled whenever stored data or View configuration would be lost/broken.
- #567 — Relation Property target/cardinality editor composes Lane B's transactional schema-evolution service.
- #568 — bidirectional Relation pair impact is surfaced and deletion remains fail-closed when the inverse Property would also be affected.

Remaining #493 work:
- reversible Property archive/delete execution semantics; no archive state exists yet;
- explicit compatible Value-type conversion inspect/plan/confirm/apply contract;
- incompatible conversion must require an explicit migration/clear-values decision and rollback on failure;
- real-host action wiring remains patch-sized presentation work.

## Validation
This connector execution path has no local Flutter checkout, so repository Flutter CI is the executable validation source.

- #592: Flutter CI run 1907 completed successfully and the PR merged.
- #595: maintainability checks, dependency guards and analyze completed successfully; test step was still in progress at the latest check.

Do not infer #595 test success until the workflow concludes.

## Shared hotspot / concurrency status
Before this run, open-PR searches found no active PR claiming `generic_database_page.dart` or `object_inspector_page.dart` broadly. Recheck immediately before edits because main changes continuously.

Shared hotspots still include:
- `generic_database_page.dart`
- `bookmark_unified_stage1_page.dart`
- `object_inspector_page.dart`
- `app_shell.dart`
- `settings_page.dart`
- `profile_manager.dart`
- `app_database.dart`

Do not reconstruct a whole hotspot for a small host integration. Prefer service/widget seams and narrowly-scoped hunks.

## Exact next actions
1. Recheck #595 CI and integrate only after relevant checks pass and the branch remains safely mergeable.
2. Wire `DatabasePropertyAuthoringService` + `PropertyAddPopover` into the real generic Database Property-add host; do not write Relation config directly in the widget.
3. Wire the quick-create policy/action into the existing Relation value picker, delegating to canonical custom Object/Tag/Weblink/Image/File creation/import callbacks.
4. Wire generic Gallery cover compatibility + dispatcher into fixed and masonry real-host cards, then expose schema-derived cover choices in the toolbar.
5. Wire #567 Relation schema edit and #547/#568 delete-impact UX into Property management actions without bypassing canonical schema/Relation services.
6. Continue #490 only through ordinary user-owned ObjectType/Property/Relation/Database/View configuration; no domain-specific management pages.
7. Keep destructive Relation integrity in Lane B, primitive identity/import semantics in Lane D, search in Lane E, and Vault/filesystem lifecycle in Lane F.

## Cross-lane dependencies / risks
- Lane B owns Relation mutation/data-integrity and destructive target/cardinality correctness.
- Lane D owns Tag/Weblink/Image/File canonical creation/import semantics; Lane C may only select/display/invoke those boundaries.
- File/Image import routing is still active work in Primitive lane; do not create a second import classifier.
- Refactor lane is narrowing `AppDatabase`; do not add new direct presentation dependencies on it.
- No destructive Property archive/delete migration is approved; existing fail-closed behavior remains correct until a reversible storage contract exists.

## Stop reason for this run
Two coherent non-hotspot Lane C checkpoints were produced: #592 merged the fresh-workspace primitive/Paper template composition, and #595 added the quick-create presentation seam. The durable handoff was refreshed from current repository state. The next valuable work is real-host wiring in shared files; it should begin only after #595 completes validation and open-PR ownership is rechecked, rather than stacking overlapping host edits while that branch is still validating.
