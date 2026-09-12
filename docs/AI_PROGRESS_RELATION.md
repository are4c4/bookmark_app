# AI Progress — Relations & Data Integrity Lane

> Durable Lane B handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Preserve the canonical Relation subsystem; transient PR/CI/main snapshots belong to live GitHub rather than this file.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation mutation/read/index/backlink/audit/reconcile, integrity-sensitive schema evolution, deletion/reference invariants, Tag hierarchy correctness, Object-merge rewiring, durable Relation-history safety, and Relation-producing workflow atomicity.

## Canonical Relation contract
- Feature writes go through `RelationMutationService` / canonical Relation facades.
- Canonical reads use `RelationReadService` or readers enforcing the same persisted-value/index/target/cardinality contract.
- Integrity-sensitive mutation preflight uses strict stored-value/index validation and never silently repairs malformed state.
- `RelationIntegrityService` is diagnostic/read-only; deterministic index-only reconciliation is separate from user-authored serialized value repair.
- Relation-safe Object deletion/merge/history operations compose through canonical mutation APIs and transaction boundaries rather than direct `object_relation_edges` or serialized-id writes.
- Missing/wrong-type targets, duplicates, cardinality conflicts, stale index/order/position metadata, invalid bidirectional metadata and ambiguous corruption fail closed.
- No parallel domain edge store, Tag tree store, ancestor materialization, history edge store, or ad-hoc serialized-id writer.

## Object-first architecture implications
- `Bookmark` is compatibility/migration input, not a final ObjectType. Retained Bookmark relationships converge onto canonical Weblink or another explicitly chosen generic Object target without guessing or silently merging conflicting state.
- Person roles/groups use generic Objects and canonical Relations rather than a permanent People-specific relationship store.
- Tag hierarchy is generic Object/Relation persistence: `Tag --Parent--> Tag`; only direct Tags are stored on ordinary Objects and ancestors are derived.
- Roles such as Author/Member/Designer are Relation semantics, not extra ObjectTypes.
- Object merge and durable history may ask B to validate/rewire/restore Relations, but A remains owner of Object identity/redirect/history-core semantics and F remains owner of managed-byte retention.

## Integrated B contracts

### Tag hierarchy integrity and strict descendant reader — #1052 / #1105 completed
- Tag `Parent` is a canonical single Relation targeting Tag; self-parenting, indirect cycles, wrong targets, malformed state, cardinality violations and serialized/index drift fail closed.
- TagGroup is a generic ObjectType and Tag `Group` is a canonical single Relation targeting TagGroup; no second hierarchy store exists.
- Legacy Tag/TagGroup compatibility sync is preservation-safe: canonical-only Parent/Group state is not silently overwritten and canonical TagGroup Objects are not deleted merely because a legacy row is absent.
- `TagHierarchyIntegrityService.loadSnapshot()` reads strict canonical Parent state transactionally and `TagHierarchySnapshot.isStrictDescendant()` derives hierarchy in memory without persisting ancestors or a closure cache.
- C/#1053 consumes this B-owned canonical reader for hierarchy-aware query/UX rather than reading legacy `tags.parentTagId`.

### Relation-target Weblink quick-create — #1103 completed
- Relation Weblink quick-create establishes identity through the canonical `CanonicalWeblinkCaptureService` boundary.
- Equivalent normalized URLs reuse one Weblink; ambiguous canonical URL collisions fail closed before Relation mutation or ambiguous candidate return.
- Optional enrichment remains fail-soft after identity establishment, and the created/reused Object is revalidated against the configured Relation target ObjectType before selection.

### Bookmark direct Tags -> canonical Weblink Tags — #1118 completed
- Weblink `Tags` is the canonical many Relation destination for retained direct saved-URL Tag assignments.
- Bookmark `Weblink`/`Tags` and Weblink `Tags` are read through strict Relation validation; multiple Bookmarks converging on one Weblink must expose the same ordered direct Tag set or fail closed.
- `BookmarkWeblinkTagSourceSnapshot` captures the pre-Core compatibility state so reconciliation is preservation-safe: legacy-only changes can advance canonical Weblink Tags, canonical-only edits including explicit clear are preserved, and independent edits on both sides fail closed.
- Existing-workspace bootstrap is explicit and retry/restart safe; new/retargeted sources cannot overwrite a different non-empty canonical target.
- Only direct Tags are copied; Tag ancestors remain derived from canonical Parent Relations.
- Production `ObjectSyncService` composes convergence after Bookmark -> Weblink identity refresh and reports only actually mutated Weblink ids through the existing `ObjectSyncImpact` path. No Bookmark-specific Search hook or alternate Relation store exists.
- Legacy Bookmark rows and mirrored Bookmark Relations remain preserved for compatibility until later parity/caller-zero/destructive-retirement work proves them removable.

### Bookmark Images/Cover -> canonical Weblink media Relations — #1154 completed
- Mirrored Bookmark `Weblink`, ordered `Images`, and single `Cover Image` are compatibility sources; canonical destinations are Weblink `Related images` and `Representative image`, both targeting canonical Image Objects.
- Source and target media Relations are read through strict persisted-value/index/target/cardinality validation. A Bookmark cover must remain included in its ordered source Images; malformed, wrong-type, cardinality, index/order/position drift and ambiguous state fail closed before partial target mutation.
- `BookmarkWeblinkMediaSourceSnapshot` captures the pre-Core compatibility source so reconciliation is preservation-safe: legacy-only compatible changes may advance from a previously equivalent checkpoint, canonical-only target edits are preserved, and independent source+target edits fail closed.
- Multiple Bookmarks resolving to one Weblink must expose equivalent ordered Images and equivalent Cover before convergence; conflicting sources are not unioned and no cover is guessed.
- Target writes stay inside the canonical Relation subsystem through `RelationMutationService`, are applied in one workspace transaction, and are strictly reloaded after mutation.
- Legacy Bookmark/Photo compatibility rows and mirrored Bookmark Relations remain preserved; this contract adds no schemaVersion, destructive migration, preview/download behavior, Image byte authority, or alternate media/Relation store.

### Bookmark Person roles -> canonical Weblink Person Relations — #1042 / #1186 completed
- Retained Bookmark-era Person roles converge onto canonical role-bearing Weblink -> Person Relation Properties through the existing Relation subsystem.
- Arbitrary custom role names and multi-role behavior are preserved; strict Relation validation and fail-closed reconciliation prevent ambiguous source/target state from being silently unioned or overwritten.
- Multiple legacy Bookmarks resolving to one Weblink must expose compatible role/Person sets before convergence.
- Bookmark role state remains compatibility input/checkpoint only; canonical public relationship state lives on Weblink Objects.
- Together with direct Tags and media convergence, this completes the B-owned #1042 retained Bookmark-era Relation contract.

### Person roles/groups -> generic Objects + canonical Relations — #1045 completed
- Bookmark-era Person-role semantics are covered by the canonical Weblink -> Person role contract above; no second role edge store is introduced.
- Legacy Person Groups map to generic Person Group Objects with stable migration identity, and canonical membership is a many Person `Groups` Relation.
- Bootstrap/reconciliation preserves legacy rows as compatibility input and fails closed on malformed/ambiguous identity or independently conflicting legacy/canonical membership.
- Normal membership mutation is Relation-first and transactional; legacy `person_group_members` is compatibility projection rather than normal authority.
- Person Group create/rename/delete lifecycle is canonical Object-first. Group deletion delegates through canonical Relation deletion so incoming Person memberships detach while Person Objects remain.
- Profile Image remains the established canonical Person -> Image Relation.

### Tag hierarchy canonical-first compatibility mutation boundary — #1240 completed
- Surviving legacy Tag move/restore flows use `TagHierarchyCompatibilityMutationService` rather than writing compatibility hierarchy fields as authority.
- Canonical Tag `Parent` / `Group` Relations mutate first through `TagHierarchyIntegrityService`; retained `tags.parent_tag_id` / `tags.group_id` and compatibility checkpoints project only after canonical success in the same transaction.
- Subtree Group movement and parent-derived destination Group preserve retained legacy tree semantics.
- Restore rejects stale independent canonical or legacy edits.
- Cycles, malformed or wrong-target Parent/Group Relations, canonical/index drift, unmapped/canonical-only subtree members and unrepresentable TagGroup identity fail closed with no partial mutation.
- Focused regressions cover move/restore equivalence, canonical-only edits followed by compatibility mutation, corruption preservation, stale restore and idempotent retry. PR #1265 passed Format, Analyze, all four Flutter test shards, `test-health`, and `merge-gate`.
- Presentation routing remains C-owned; no parallel Tag tree/closure store was added.

### Object merge canonical Relation rewiring — #1259 completed
- `RelationObjectMergeService` is the B-owned boundary that must run before A retires/deletes a merged Object identity.
- Planning validates the current Object identity and whole-workspace canonical Relation integrity without opportunistic repair, then inventories incoming and outgoing Relation effects for `retiredObjectId -> survivorObjectId`.
- Incoming retargeting preserves target order. Duplicate targets, cardinality violations, wrong target ObjectTypes, malformed serialized state, normalized-index drift and invalid bidirectional pair metadata remain explicit blockers.
- Survivor/retired outgoing Relation values are automatically compatible only when identical in order or one side is empty; different non-empty values block rather than being unioned, reordered or silently chosen.
- Execution re-plans inside the transaction to reject stale plans, clears/reassigns only through `RelationMutationService` / `BidirectionalRelationStore`, and composes with an outer A-owned merge transaction so later finalization failure rolls back Relation rewrites.
- The impact reports exact changed surviving source Object ids for downstream refresh while B never deletes the retired Object or persists redirects/scalar/Body/alias/Search/View state.
- PR #1296 passed latest-main Format, Analyze, all four Flutter test shards, `test-health`, and `merge-gate`; #1259 is a completed checkpoint.

### Durable Relation history checkpoint and restore — #1267 completed
- `ObjectHistoryRelationSnapshot` preserves immutable historical evidence for one source Object + Relation Property: exact ordered historical target ids, source/target ObjectType ids, one/many cardinality and complete managed bidirectional pair role/inverse metadata where applicable.
- Capture is allowed only from a currently healthy canonical Relation graph; malformed persisted values, missing/wrong-type targets, serialized/index drift or invalid pair metadata fail before a checkpoint is returned.
- Historical target ids never change merely because an Object is later retired. Restore planning may receive an explicit historical-id -> current-id resolution from A-owned redirect semantics, but does not rewrite the historical snapshot.
- Restore planning revalidates the current persisted source Object, Relation Property definition, target ObjectType, cardinality and bidirectional contract. Missing resolution, live-target remapping, duplicate redirect convergence, schema/cardinality drift and inverse single-cardinality conflicts remain blockers rather than silent normalization.
- Execution re-previews inside the transaction to reject stale plans, applies through `RelationMutationService`, post-audits canonical integrity and composes with an outer restore transaction so later failure rolls back all Relation mutations.
- The plan/impact exposes blockers and exact changed Object ids without exposing raw edge/index authority to A.
- Focused regressions cover ordered JSON round-trip, bidirectional metadata, index corruption, explicit retired-target resolution, duplicate convergence, cardinality/pair conflicts, successful bidirectional restore, stale plans and outer rollback. PR #1302 passed latest-main Format, Analyze, all four Flutter test shards, `test-health`, and `merge-gate`; #1267 is a completed checkpoint.
- This slice added no durable history table/migration, timeline UI, managed-byte retention authority, event sourcing or parallel Relation-history store.

## Current B roadmap / resume contract

Completed checkpoints include **#1042, #1045, #1240, #1259 and #1267**. Do not reopen them or create Person/Bookmark/Tag/Object-merge/history-specific parallel Relation authorities merely to keep B active.

Resume B only from one of the following, after live duplicate-ownership/hotspot/migration checks:
- a newly opened focused B Issue with a demonstrated current-main Relation/integrity obligation;
- an explicitly split follow-up from #1062 that requires additional canonical Relation merge/redirect integrity beyond completed #1259;
- an explicitly split follow-up from #1064 that requires additional canonical Relation-history persistence/restore integrity beyond completed #1267;
- another owning-lane dependency routed to B because it requires a concrete canonical Relation contract;
- an evidence-backed correctness/integrity gap found on current `main`, after creating/refining one focused Issue rather than silently broadening an umbrella.

At the final post-#1267 resume audit there was no other live focused B Issue or newly unblocked concrete B acceptance slice. The resulting stop category was **`idle-no-work`**. This is a historical stop checkpoint, not a claim about future GitHub state: every new B run must re-query live Issues/PRs/main before deciding whether the lane remains idle.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Bookmark -> Weblink reconciliation authority, Person identity authority, Body, merge/history core contracts and redirect resolution.
- **C:** Database/View/schema presentation, Tag hierarchy filter/picker UX, Stage1/People generic UI replacement.
- **D:** Weblink/Image/File native identity/media behavior and native-capability prerequisites. B consumes these boundaries but does not redesign them.
- **E:** Search projection consumes canonical Object/Relation impact and must not create Bookmark/Person-specific long-term indexing.
- **F:** Vault/storage/managed-byte preservation, history byte-retention/GC and destructive-retirement evidence.
- **G:** caller-zero legacy code deletion only after owning product lanes prove parity; CI/developer-workflow health remains G-owned.

## Hotspot / migration rule
Prefer Relation services/domain/tests and avoid broad presentation hotspots. `ObjectSyncService` may receive a patch-sized composition hook when a focused B acceptance explicitly requires production reconciliation. Any schema/migration-changing slice is single-writer and must use the repository hard gate. Do not edit Stage1/People/GenericDatabasePage merely because those workflows produce Relations.

## Validation
Analyze + relevant Relation regressions + full Flutter Test + required `merge-gate` are part of integrity acceptance. Corruption tests should prove no partial mutation and no opportunistic repair. GitHub CI is authoritative when local Flutter execution is unavailable.

## Resume sequence
1. Re-read latest `main`, open focused B Issues, open PR ownership, shared hotspots, migration-writer ownership and current CI.
2. Treat #1042, #1045, #1240, #1259 and #1267 as completed checkpoints, not active work queues.
3. Recheck #1062/#1064 and other owning-lane work only for a newly split concrete B dependency; do not infer an implementation task from an umbrella alone.
4. If no focused dependency or demonstrated current-main integrity gap exists, stop as `idle-no-work` instead of inventing Relation abstractions, alternate stores, closure caches, history ledgers or speculative migrations.

This sequence is not terminal. After every future slice/PR/merge, apply the shared Lane continuation and resume/stop contract in `AGENTS.md` before ending the run.
