# AI Progress — Relations & Data Integrity Lane

> Durable Lane B handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Preserve the canonical Relation subsystem; historical implementation detail remains in git/Issue/PR history.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation mutation/read/index/backlink/audit/reconcile, integrity-sensitive schema evolution, deletion/reference invariants, Tag hierarchy correctness, and Relation-producing workflow atomicity.

## Canonical Relation contract
- Feature writes go through `RelationMutationService` / canonical Relation facades.
- Canonical reads use `RelationReadService` or readers enforcing the same persisted-value/index/target/cardinality contract.
- Integrity-sensitive mutation preflight uses strict stored-value/index validation and never silently repairs malformed state.
- `RelationIntegrityService` is diagnostic/read-only; deterministic index-only reconciliation is separate from user-authored serialized value repair.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Missing/wrong-type targets, duplicates, cardinality conflicts, stale index/order/position metadata and ambiguous corruption fail closed.
- No parallel domain edge store, Tag tree store, or ad-hoc serialized-id writer.

## Object-first architecture implications
- `Bookmark` is not a final ObjectType. Legacy Bookmark relationships must converge onto canonical Weblink or another explicitly chosen generic Object target without guessing/merging conflicting user data.
- Person roles/groups must converge onto generic Relation/Database/Tag semantics rather than a permanent People-specific relationship store.
- Tag hierarchy is generic Object/Relation persistence: `Tag --Parent--> Tag`; only direct tags are stored on ordinary Objects, ancestors are derived.
- Roles such as Author/Member/Designer are Relation semantics, not extra ObjectTypes.

## Active focused issues

### #1052 — Tag hierarchy integrity
Primary Tag-hierarchy correctness slice. Active implementation: PR #1095 on `feature/tag-hierarchy-integrity-1052`.

Implemented on the active branch:
- canonical Tag -> Parent(Tag) relation with cardinality 0..1;
- strict mutation preflight rejects malformed values, missing/wrong-type targets, cardinality violations and normalized-edge drift before mutation;
- self-parenting and indirect cycles fail before partial mutation;
- TagGroup is a generic ObjectType and Tag -> Group(TagGroup) is a canonical single Relation, without a second hierarchy store;
- legacy Tag/TagGroup projection is preservation-safe: canonical TagGroup Objects are not deleted merely because legacy rows disappear, canonical-only Parent/Group edits are not silently overwritten, one-sided legacy changes can reconcile, and ambiguous independent edits fail closed;
- `TagHierarchyIntegrityService.loadSnapshot()` exposes a transactionally consistent read-only snapshot from canonical Parent Relations only. `TagHierarchySnapshot.isStrictDescendant()` derives ancestors/descendants in memory for C/#1053 and stores no ancestor list or closure cache;
- snapshot loading applies strict Relation value/index/target/cardinality validation to every Tag and rejects an already-persisted cycle rather than hiding corruption;
- direct Object -> Tag assignments remain independent of derived ancestors.

Validation evidence on runtime head `4ea94151e5d5de1d2f0c76a48c932a4a9cdf16d5`:
- all four Flutter Test shards and `test-health` are green;
- required Format/Analyze are currently prevented from starting by repository CI Issue #1106 (stale original PR base SHA absent from the shallow checkout), not by a B test failure;
- do not recreate #1095 merely to bypass #1106 unless repository coordination explicitly changes; rerun authoritative Format/Analyze after the G-owned guard fix lands.

No descendant-filter UI/query implementation here; C/#1053 owns query semantics and presentation and can consume the snapshot matcher after #1052 integrates.

### #1042 — Bookmark retirement relations
Audit legacy Bookmark -> Weblink, Images/Cover Image, Tags and Person/role relationships and define the canonical target for each retained relationship. Multiple legacy Bookmarks collapsing onto one normalized Weblink must never silently merge conflicting Relation state.

Current dependency: relation convergence needs the D/#1054 canonical Weblink identity boundary and A/#1041 Bookmark -> canonical Weblink reconciliation semantics before B can safely choose/rewire canonical Relation sources in collision cases.

### #1045 — Person groups/roles
Map Person groups and Bookmark-era Person roles onto generic Relation/Database/Tag contracts. Preserve visible role/cardinality/order semantics and Profile Image Relation. No dedicated People UI replacement here.

Current dependency: Bookmark-era role convergence depends on #1042. The existing `PersonObjectBridge` still declares legacy People rows authoritative while A/#1044 owns the Person authority transition; do not create a second Person grouping authority or prematurely choose a lossy Tag/Database projection while that identity contract remains unsettled.

## Integrated foundation that remains authoritative
The existing canonical Relation subsystem already provides:
- strict persisted Relation-value inspection;
- target ObjectType/cardinality validation;
- stored-value/index count/order/position consistency checks;
- canonical backlinks and graph/read projections;
- Relation-safe Object deletion/detach;
- bidirectional Relation lifecycle;
- deterministic index-only reconcile paths;
- transaction/rollback-safe Relation-producing workflows;
- strict mutation preflight used by Bookmark Image and Person Profile Image compatibility paths.

Older statements that Lane B is idle after #895/#947 are obsolete because #1042/#1045/#1052 are now open focused B issues.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Bookmark→Weblink generic identity contract, Person identity authority, Body.
- **C:** Database/View/schema presentation, Tag hierarchy filter/picker UX, Stage1/People generic UI replacement.
- **D:** Weblink/Image/File native identity/media behavior and direct URL capture.
- **E:** Search projection; Search consumes integrity-filtered Relation labels/impact and must not bypass B contracts.
- **F:** Vault/storage preservation.
- **G:** caller-zero legacy code deletion only after B and owning product lanes prove parity; repository CI/developer-workflow guard fixes such as #1106 remain G-owned.

## Hotspot / migration rule
Prefer Relation services/domain/tests and avoid broad presentation hotspots. Any schema/migration-changing slice is single-writer and must be coordinated explicitly through the repository hard gate. Do not edit Stage1/People/GenericDatabasePage merely because their workflows produce Relations unless the focused B acceptance requires a patch-sized integrity hook.

## Validation
Analyze + relevant Relation regressions + full Flutter Test are part of integrity acceptance. Corruption tests should prove no partial mutation and no opportunistic repair.

## Resume sequence
1. re-read live #1052/#1042/#1045, #1106 while relevant, current PR ownership and latest `main`;
2. finish #1052 authoritative Format/Analyze after the G-owned #1106 guard defect is resolved, then merge only if the required aggregate gate is green;
3. after #1052 integration, hand C/#1053 the canonical `TagHierarchySnapshot.isStrictDescendant` boundary rather than legacy Tag hierarchy state;
4. refresh live B work and choose the next focused Issue; D/#1054 may also hand B the remaining Relation-target Weblink quick-create caller after its canonical capture boundary integrates;
5. implement the smallest integrity kernel below presentation and add healthy + corrupt/rollback/delete/backlink regressions;
6. remain idle rather than inventing Relation abstractions if all focused B work becomes dependency-blocked.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane B must re-check unfinished acceptance, same-umbrella follow-ups, live B focused Issues and newly-unblocked integrity work before declaring idle. If no safe B work remains, record `Stop reason: idle-no-work — <live evidence>` or the more precise shared stop category in the durable handoff; dependency-blocked work is `Stop reason: dependency — <blocking Issue/PR/evidence>`, not generic idle.

## Current stop state
Stop reason: dependency — #1052 runtime/full Flutter Test is green but required Format/Analyze/merge-gate cannot execute because G-owned #1106 blocks stale-base PR #1095 before Flutter setup. Final live audit found #1042 dependent on open D/#1054 PR #1108 plus A/#1041 reconciliation semantics, and #1045 role work dependent on #1042 while its grouping authority should not precede A/#1044 Person authority convergence. Resume immediately by rechecking #1106; once fixed, rerun #1095 required validation and merge if green, then refresh #1042/#1045 and D's Relation-target quick-create handoff.
