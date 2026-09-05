# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image workflow

Cross-lane coordination:
- `#225` — Refactor lane migration/hotspot work; Relation lane audits concrete Relation boundaries and does not co-own unrelated refactors.

`#166` alias-aware Relation picker is complete/closed.

## Current checkpoint
Latest audited `main`: `c69d7b067c56a5e195e15f7a4691a3a1d3b57319` (`#273` Relation composition-root regression), based on merged Refactor `#275` v4 migration extraction.

Latest Relation checkpoints:
- `#266` `Exercise canonical Relation facade after legacy migration` — merged; CI #1055 success.
- `#271` `Cover canonical Relation bootstrap from v4 migration` — merged as `fdd5e4ac0eb990bdd9bab68ca68abe425ea84159`; CI #1069 success.
- Object `#272` wired canonical Weblink/Image creation services into real `GenericDatabasePageServices.fromStores()` without changing Relation wiring.
- `#273` `Cover Relation attach from real system creation services` — merged as `c69d7b067c56a5e195e15f7a4691a3a1d3b57319`; latest replay CI #1092 success.

## Canonical Relation contract
- `RelationMutationService` is the user-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs only deterministic index drift from persisted Relation values.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional corruption is never auto-repaired from editor paths.
- no Weblink/Image-specific Relation persistence service or alternate index exists.
- normal feature code must not directly serialize Object ids into persisted Relation values or maintain a parallel Relation index.

## Stable production coverage
Merged Relation coverage includes:
- `#174–#177` — Bookmark/Weblink and Weblink/Image boundary integrity/guardrails.
- `#182/#184/#188` — live Bookmark -> Weblink retarget, detach/delete, shared targets, index reconcile.
- `#190/#192` — production Weblink -> Image target/cardinality/lifecycle.
- `#195/#200/#202` — alias-aware Relation candidate search and real picker, canonical ids only.
- `#198/#201` — managed preview pipeline + real ObjectSync host retry/replacement/index/backlink/delete lifecycle.
- `#208/#210/#211/#216` — exposed Weblinks host edit/backlink/delete/composite delete lifecycle.
- `#222` — exposed Images host backlink/delete lifecycle.
- `#273` — real page-services composition root creates/reuses Weblink/Image identities, then attaches production Representative/Related Image Relations through `relationEditor`; repeated saves remain idempotent and read/backlink/audit stay healthy.

Current real generic hosts are covered for canonical values, normalized edges, backlinks, delete/detach and healthy workspace audit across the Weblink/Image surfaces introduced so far.

## Historical migration / Refactor boundary
Refactor lane is extracting historical `AppDatabase` migrations under `#225`. Relation ownership remains narrow:

- legacy `bookmark_people` and legacy `bookmark_relations` are compatibility-era Bookmark tables, not the canonical generic Object Relation subsystem;
- canonical normalized Relation state uses persisted Object Relation values plus lazy `object_relation_edges` ensured by `ObjectStore`;
- `object_relation_edges` is not created by the historical AppDatabase migration sequence.

Relation guardrails:
- `#264` proves v9-era legacy `bookmark_people` / `bookmark_relations` survive while canonical Object Relation lazy bootstrap creates correct outgoing/backlinks without mutating legacy rows.
- `#266` strengthens that boundary through `RelationMutationService`, `RelationReadService`, and `RelationIntegrityService` rather than only low-level storage.
- `#271` proves the same canonical facade/read/audit/index bootstrap after a real v4 -> current migration, including the later v5 `bookmark_people` and v9 `bookmark_relations` steps.

Relevant audited Refactor work:
- `#248` v10 bookmark-people migration extraction — behavior preserved.
- `#258` v9 workflow migration extraction including legacy `bookmark_relations` creation — no canonical Relation persistence introduced.
- `#267` v5 People/BookmarkPeople creation extraction — protected by `#271`.
- `#269/#270` historical v3/v2 compatibility fixes — no canonical Relation semantics changed.
- `#275` v4 SavedView migration extraction — exact helper move; CI #1088 success with Relation guardrails in the suite.
- open `#276` v3 extraction moves historical tag DDL/normalization into a helper without touching canonical Relation storage/index.

Do not add a Relation regression for every migration version mechanically. Add/strengthen one only when a migration actually crosses a Relation boundary or breaks an existing guardrail.

## Object-lane audit
Object creation now has canonical system-collection boundaries:
- `#250` canonical Weblink URL creation/reuse.
- `#263` canonical managed Image collection creation/reuse.
- `#265` managed Image import workflow; no Relation write.
- `#272` wires Weblink/Image creation services into real `GenericDatabasePageServices.fromStores()` while retaining canonical `relationEditor` wiring.

`#273` closes the Relation follow-up to `#272`: objects created/reused through that real composition root can be attached to production Weblink->Image Relation properties without duplicate normalized edges, and resolved backlinks/audit stay correct.

Latest default-branch `setRelation` audit found no new view-level low-level bypass. Feature paths continue to use `RelationMutationService` (for example Relation editor, Bookmark->Weblink bridge, preview Image pipeline, Tag bridge, promotion execution).

## Validation
Latest Relation-specific validation:
- `#264` CI #1006 — success.
- `#266` CI #1055 — success.
- `#271` CI #1069 — success.
- `#273` initial CI #1084 — success before later Refactor merges.
- `#273` replay CI #1092 — success on top of merged `#275` v4 extraction; merged as `c69d7b067c56a5e195e15f7a4691a3a1d3b57319`.
- Refactor `#275` CI #1088 — success and therefore existing Relation guardrails remained green under that extraction.

Earlier important green Relation runs remain #811/#819/#823/#825/#828, #853/#855/#890/#891/#902.

## Cross-lane ownership / conflict policy
Refactor lane is actively changing historical `app_database.dart` migration sequencing. Relation lane must not co-own those helpers unless canonical Relation schema/index behavior is actually moved or changed.

Before touching shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`), re-check open PR ownership and prefer tests-only or Relation-internal changes. The recent Relation migration work (`#264/#266/#271`) and composition-root follow-up (`#273`) intentionally changed tests only.

Do not overwrite `docs/AI_PROGRESS.md` merely to record lane-local details while Refactor/Object agents are advancing repository-wide state quickly; update it only for a real repository-wide coordination change and after checking concurrent ownership.

## Exact next Relation actions
1. Monitor Object work for a genuinely new Relation-producing workflow: user-facing import/create that also attaches a Relation, explicit `Related images` population, Object merge/dedup, new first-class Object migration, or a new retarget/detach path.
2. Audit new workflows for direct serialized ids or low-level `ObjectStore.setRelation` bypass before adding tests.
3. Add focused lifecycle/idempotency/backlink/index/delete regression only when the workflow or a concrete defect is new.
4. Continue auditing Refactor migration extraction only at actual Relation boundaries. If lazy `object_relation_edges` ensure logic moves out of `ObjectStore`, require Relation-owned index/backlink/reconcile coverage before integration.
5. Do not invent automatic Object merge/dedup Relation rewrites without an explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains intentionally prohibited.
- Future Object merge/deduplication needs an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` and canonical Object Relations must remain separate until an explicit migration product contract says otherwise.
- During the old #219 replay, a transient note file was created and immediately deleted on `main`; the two commits have net-zero tree effect. Do not rewrite main history for that.

## Stop reason
`#266/#271` close the currently actionable historical-migration/Relation boundary, and `#273` closes the newly exposed real Weblink/Image creation-composition-root Relation attach boundary. Open Refactor `#276` is a behavior-preserving historical tag migration extraction and does not change canonical Relation storage/index. No new independent Relation implementation remains without duplicating existing coverage or competing with another lane's ownership. Resume when another lane introduces a new Relation-producing workflow, moves canonical Relation storage/index behavior, or exposes a concrete correctness regression.
