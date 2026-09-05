# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image workflow

Cross-lane coordination:
- `#225` — Refactor lane migration/hotspot work; Relation lane audits only concrete Relation boundaries and does not co-own unrelated refactors.

`#166` alias-aware Relation picker is complete/closed.

## Current checkpoint
Latest audited `main`: `c010dc38966478f0a99224368c36554ac7e1ba68` (`#257` v5 photo migration compatibility fix), whose parent contains Relation PR #264.

Latest Relation checkpoint:
- #264 `Cover Relation bootstrap after legacy migration`
- squash merge `04f7f7e4e368f6390bba38862e27ab8cd831c343`
- strengthened head `6c62f6a27e77e24b571b8925e1adf62718d09378`
- Flutter CI #1006: success

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
Earlier merged coverage remains valid:
- #174–#177 — Bookmark/Weblink and Weblink/Image boundary integrity/guardrails.
- #182/#184/#188 — live Bookmark -> Weblink retarget, detach/delete, shared targets, index reconcile.
- #190/#192 — production Weblink -> Image target/cardinality/lifecycle.
- #195/#200/#202 — alias-aware Relation candidate search and real picker, canonical ids only.
- #198/#201 — managed preview pipeline + real ObjectSync host retry/replacement/index/backlink/delete lifecycle.
- #208/#210/#211/#216 — exposed Weblinks host edit/backlink/delete/composite delete lifecycle.
- #222 — exposed Images host backlink/delete lifecycle.

Current real generic hosts are covered for canonical values, normalized edges, backlinks, delete/detach and healthy workspace audit across the Weblink/Image surfaces introduced so far.

## Historical migration / Refactor boundary
The Refactor lane is extracting historical `AppDatabase` migration bodies under #225. Relation ownership remains narrow:

- legacy `bookmark_people` and legacy `bookmark_relations` are compatibility-era Bookmark tables, not the canonical generic Object Relation subsystem;
- canonical normalized Relation state uses persisted Object Relation values plus lazy `object_relation_edges` ensured by `ObjectStore`;
- `object_relation_edges` is not currently created by the historical AppDatabase migration sequence.

Relevant audited Refactor work:
- #248 merged v10 `bookmark_people` migration-body extraction; statement order and `出演` / `performer` -> `出演者` normalization semantics were preserved.
- #258 merged v9 workflow migration-body extraction, including legacy `bookmark_relations` table creation; no canonical generic Relation persistence was introduced there.
- #257 merged v5->current Photo migration compatibility guard for `photos.tags`; it is Relation-neutral.

### #254 -> #264 Relation safety regression
#254 introduced a tests-only cross-lane regression but its first CI #973 failed because the minimal historical Bookmark fixture was passed through `WorkspaceStore.initialize()`, whose current Drift Bookmark mapper requires columns not present in that intentionally old fixture. This was fixture-only, not a Relation failure.

The test was corrected to create a current workspace directly after migration. Corrected #254 CI #992 passed, but Refactor work had advanced `main`, so #254 was closed as superseded and cleanly replayed as #264.

#264 now proves on a real v9-era migration fixture that:
- the legacy `bookmark_people` row survives and normalizes to `出演者`;
- an existing legacy `bookmark_relations` row survives unchanged;
- after the historical database reaches current schema, the generic Object layer can create ObjectTypes/Objects and a canonical Relation;
- the lazy `object_relation_edges` table/index bootstraps successfully;
- canonical outgoing/backlink state is correct;
- writing the canonical Object Relation does not mutate either legacy relation-like table.

This guards coexistence while Refactor continues historical migration extraction without coupling legacy Bookmark graphs to the canonical Object Relation graph.

## Current Object-lane audit
Object creation work has advanced, but no new Relation-producing workflow exists yet:
- #250 merged `createWeblinkFromUrl(...)`, delegating canonical URL normalization/reuse to `WeblinkObjectService`; no Relation write/index path.
- #263 merged `createImageFromManagedFile(...)`, delegating canonical managed-file identity/reuse to `ImageObjectService.findOrCreateManaged(...)`; no Relation write/index path.
- #253 is the focused Weblink URL-entry dialog and remains Object-owned; it does not itself persist Relations.
- #221/#223 remain read-only Weblink Gallery/media presentation; #223 owns `generic_database_page.dart` while open.

Existing Relation tests already use managed Image Objects as real targets of production Representative/Related Relations, so wrapping Image creation through #263 does not create a new Relation semantic requiring duplicate coverage by itself.

## Validation
Latest Relation-specific validation:
- #254 initial CI #973 — failed only in historical fixture setup before Relation bootstrap.
- #254 corrected CI #992 — success.
- #264 strengthened CI #1006 — success; merged as `04f7f7e4e368f6390bba38862e27ab8cd831c343`.

Earlier important green Relation runs remain #811/#819/#823/#825/#828, #853/#855/#890/#891/#902.

## Cross-lane ownership / conflict policy
Refactor lane is actively changing historical `app_database.dart` migration sequencing through small protected extractions. Relation lane must not co-own those version helpers unless canonical Relation schema/index behavior is actually moved or changed.

Object lane currently owns system-collection creation/presentation and `generic_database_page.dart` through #223. Before touching shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`), re-check open PR ownership and prefer tests-only or Relation-internal changes.

Do not overwrite `docs/AI_PROGRESS.md` merely to record lane-local details while Refactor/Object agents are advancing repository-wide state quickly; update it only for a real repository-wide coordination change and after checking concurrent ownership.

## Exact next Relation actions
1. Monitor Object work for a genuinely new Relation-producing workflow: user-facing import/create that also attaches a Relation, explicit `Related images` population, Object merge/dedup, new first-class Object migration, or a new retarget/detach path.
2. Audit each new workflow for direct serialized ids or low-level `ObjectStore.setRelation` bypass before adding tests.
3. Add focused lifecycle/idempotency/backlink/index/delete regression only when the new workflow or a concrete defect exists.
4. Continue auditing Refactor migration extraction only at actual Relation boundaries. If lazy `object_relation_edges` ensure logic moves out of `ObjectStore`, require Relation-owned index/backlink/reconcile regressions before integration.
5. Do not invent automatic Object merge/dedup Relation rewrites without an explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains intentionally prohibited.
- Future Object merge/deduplication needs an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` and canonical Object Relations must remain separate until an explicit migration product contract says otherwise.
- During the old #219 replay, a transient note file was created and immediately deleted on `main`; the two commits have net-zero tree effect. Do not rewrite main history for that.

## Stop reason
#264 closed the only newly actionable Relation/Refactor boundary: historical migration can now coexist with canonical Relation lazy bootstrap without mutating legacy Bookmark relation tables. Current Object #250/#263 creation services are identity-safe but do not create Relations; #253 and #221/#223 are UI/presentation work. Current Refactor v5-v8 migration work does not modify canonical Relation schema/index state. Therefore no independent Relation implementation remains without creating duplicate/speculative coverage or competing with another lane's hotspot ownership. Resume when another lane introduces a new Relation-producing workflow, moves canonical Relation storage/index behavior, or exposes a concrete correctness regression.
