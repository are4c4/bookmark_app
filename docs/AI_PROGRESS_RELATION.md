# AI Progress — Relations & Data Integrity Lane

> Durable Lane B handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Preserve the canonical Relation subsystem; transient PR/CI/main snapshots belong to live GitHub rather than this file.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation mutation/read/index/backlink/audit/reconcile, integrity-sensitive schema evolution, deletion/reference invariants, Tag hierarchy correctness, and Relation-producing workflow atomicity.

## Canonical Relation contract
- Feature writes go through `RelationMutationService` / canonical Relation facades.
- Canonical reads use `RelationReadService` or readers enforcing the same persisted-value/index/target/cardinality contract.
- Integrity-sensitive mutation preflight uses strict stored-value/index validation and never silently repairs malformed state.
- `RelationIntegrityService` is diagnostic/read-only; deterministic index-only reconciliation is separate from user-authored serialized value repair.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Missing/wrong-type targets, duplicates, cardinality conflicts, stale index/order/position metadata and ambiguous corruption fail closed.
- No parallel domain edge store, Tag tree store, ancestor materialization, or ad-hoc serialized-id writer.

## Object-first architecture implications
- `Bookmark` is compatibility/migration input, not a final ObjectType. Retained Bookmark relationships converge onto canonical Weblink or another explicitly chosen generic Object target without guessing or silently merging conflicting state.
- Person roles/groups use generic Objects and canonical Relations rather than a permanent People-specific relationship store.
- Tag hierarchy is generic Object/Relation persistence: `Tag --Parent--> Tag`; only direct Tags are stored on ordinary Objects and ancestors are derived.
- Roles such as Author/Member/Designer are Relation semantics, not extra ObjectTypes.

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
- A canonical/preview-derived Weblink Representative image is valid independently of Related images and is never auto-added merely to normalize Bookmark-era semantics.
- Multiple Bookmarks resolving to one Weblink must expose equivalent ordered Images and equivalent Cover before convergence; conflicting sources are not unioned and no cover is guessed.
- Target writes stay inside the canonical Relation subsystem through `RelationMutationService`, are applied in one workspace transaction, and are strictly reloaded after mutation so serialized/index/backlink state remains canonical.
- Production `ObjectSyncService` captures media before Core compatibility refresh, reconciles after Bookmark -> Weblink identity refresh, and reports only actually mutated Weblink ids through the existing `ObjectSyncImpact` path.
- Legacy Bookmark/Photo compatibility rows and mirrored Bookmark Relations remain preserved; this contract adds no schemaVersion, destructive migration, preview/download behavior, Image byte authority, or alternate media/Relation store.

### Bookmark Person roles -> canonical Weblink Person Relations — #1042 / #1186 completed
- Retained Bookmark-era Person roles converge onto canonical role-bearing Weblink -> Person Relation Properties through the existing Relation subsystem.
- Arbitrary custom role names and multi-role behavior are preserved; strict Relation validation and fail-closed reconciliation prevent ambiguous source/target state from being silently unioned or overwritten.
- Multiple legacy Bookmarks resolving to one Weblink must expose compatible role/Person sets before convergence.
- Bookmark role state remains compatibility input/checkpoint only; the canonical public relationship state lives on Weblink Objects.
- Together with direct Tags and media convergence, this completes the B-owned #1042 retained Bookmark-era Relation contract. #1042 is a completed checkpoint, not an active B work queue.

### Person roles/groups -> generic Objects + canonical Relations — #1045 completed
- Bookmark-era Person-role semantics are covered by the canonical Weblink -> Person role contract above; no second role edge store is introduced.
- Legacy Person Groups map to generic Person Group Objects with stable migration identity, and canonical membership is a many Person `Groups` Relation.
- Bootstrap/reconciliation preserves legacy rows as compatibility input and fails closed on malformed/ambiguous identity or independently conflicting legacy/canonical membership.
- Normal membership mutation is Relation-first and transactional; legacy `person_group_members` is compatibility projection rather than normal authority.
- Person Group create/rename/delete lifecycle is canonical Object-first. Group deletion delegates through canonical Relation deletion so incoming Person memberships detach while Person Objects remain.
- Profile Image remains the established canonical Person -> Image Relation and is not replaced by the group/role convergence work.
- Remaining People-retirement work belongs to generic C daily-use parity, Search freshness where applicable, and later G caller-zero/preservation sequencing rather than another B relationship authority.

### Tag hierarchy canonical-first compatibility mutation boundary — #1240 completed
- Surviving legacy Tag move/restore flows use `TagHierarchyCompatibilityMutationService` rather than writing compatibility hierarchy fields as authority.
- Canonical Tag `Parent` / `Group` Relations are mutated first through `TagHierarchyIntegrityService`; retained `tags.parent_tag_id` / `tags.group_id` and existing compatibility checkpoints are projected only after canonical success, inside the same transaction.
- A moved canonical subtree receives the resolved destination TagGroup so retained legacy tree semantics remain equivalent; when a selected parent already has a canonical Group, that parent Group determines the destination rather than silently preserving a conflicting caller Group.
- Move snapshots preserve the previous canonical/compatibility state needed for restore, and restore rejects stale independent canonical or legacy edits instead of overwriting them.
- Cycles, malformed Relation values, wrong-target Parent/Group Relations, canonical/index drift, unmapped or canonical-only subtree members, and unrepresentable TagGroup identity fail closed with no partial canonical or compatibility mutation.
- Focused regressions cover move/restore equivalence, canonical-only edits followed by explicit compatibility mutation, cycle rollback, malformed and wrong-target preservation, stale restore rejection, and idempotent retry. PR #1265 was validated on latest main with Format, Analyze, all four Flutter test shards, `test-health`, and `merge-gate` green.
- This boundary does not create a parallel Tag tree/closure store and does not itself edit the Tag management UI; presentation routing remains C-owned.

## Active B roadmap

#1042, #1045, and #1240 are completed migration/integrity checkpoints. Do not reopen them or create more Person/Bookmark/Tag-specific relationship stores merely to keep B active.

Current focused priorities:
- **#1259 / #1062 Object merge Relation rewiring:** next cross-lane critical dependency. B must preview, validate and canonically apply `retiredObjectId -> survivorObjectId` Relation rewrites before A may retire/delete the merged Object. Preserve ordering/cardinality/bidirectional invariants and fail closed on ambiguous outgoing state.
- **#1267 / #1064 History Relation restore:** ready secondary B work after the merge Relation slice unless a newer higher-priority concrete integrity dependency supersedes it.

Resume B only from:
- an already-open focused B Issue with a demonstrated current-main Relation/integrity obligation, preferring #1259 while it remains open and unowned;
- an explicitly split #1062 Object-merge Relation rewiring/integrity slice;
- an explicitly split #1064 durable-history Relation restore/integrity slice;
- another owning-lane dependency that requires a concrete canonical Relation contract and is routed to B through a focused Issue;
- otherwise a newly demonstrated current-main Relation/integrity correctness gap.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Bookmark -> Weblink reconciliation authority, Person identity authority, Body, merge/history core contracts.
- **C:** Database/View/schema presentation, Tag hierarchy filter/picker UX, Stage1/People generic UI replacement.
- **D:** Weblink/Image/File native identity/media behavior, canonical URL capture and Weblink/Image schema/native capabilities. B consumes these boundaries but does not redesign them.
- **E:** Search projection consumes canonical Object/Relation impact and must not create Bookmark/Person-specific long-term indexing.
- **F:** Vault/storage/managed-byte preservation and destructive-retirement evidence.
- **G:** caller-zero legacy code deletion only after owning product lanes prove parity; CI/developer-workflow health remains G-owned.

## Hotspot / migration rule
Prefer Relation services/domain/tests and avoid broad presentation hotspots. `ObjectSyncService` may receive a patch-sized composition hook when a focused B acceptance explicitly requires production reconciliation. Any schema/migration-changing slice is single-writer and must use the repository hard gate. Do not edit Stage1/People/GenericDatabasePage merely because those workflows produce Relations.

## Validation
Analyze + relevant Relation regressions + full Flutter Test + required `merge-gate` are part of integrity acceptance. Corruption tests should prove no partial mutation and no opportunistic repair. GitHub CI is authoritative when local Flutter execution is unavailable.

## Resume sequence
1. Re-read latest `main`, open B Issues, open PR ownership, shared hotspots and current CI.
2. Treat #1042, #1045, and #1240 as completed checkpoints; do not select them as active work sources.
3. While open and unowned, prefer #1259 as the current Object-merge integrity dependency; then consider #1267 or another explicitly routed focused B Issue.
4. If no such work exists, apply the `AGENTS.md` next-work discovery order and stop with the precise live reason rather than inventing Relation abstractions, alternate stores, closure caches or speculative migrations.

This sequence is not terminal. After every slice/PR/merge, apply the shared Lane continuation and resume/stop contract in `AGENTS.md` before ending the run.
