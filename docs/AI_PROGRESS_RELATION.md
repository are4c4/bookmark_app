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
- Person roles/groups must converge onto generic Relation/Database/Tag semantics rather than a permanent People-specific relationship store.
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

## Active B roadmap

### #1042 — Bookmark retirement relations umbrella
Retained saved-URL relations must end on canonical Weblink/generic Object targets. Direct Tags and Images/Cover convergence are complete. Re-audit the umbrella against current main before closing/refining it; any remaining Bookmark-era Person/role semantics must have an explicit generic canonical destination and integrity contract rather than being silently folded into Weblink convergence.

### #1045 — Person groups/roles
After #1042's Weblink-side retained Relation slices are complete, map Bookmark-era Person roles and legacy Person grouping onto explicit generic Relation/Database/Tag contracts. Preserve Profile Image Relation, role/cardinality/order semantics and fail closed on ambiguous legacy/canonical state. Coordinate with A/#1044 Person authority and do not create a second Person grouping authority.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Bookmark -> Weblink reconciliation authority, Person identity authority, Body.
- **C:** Database/View/schema presentation, Tag hierarchy filter/picker UX, Stage1/People generic UI replacement.
- **D:** Weblink/Image/File native identity/media behavior, canonical URL capture and Weblink/Image schema/native capabilities. B consumes these boundaries but does not redesign them.
- **E:** Search projection consumes canonical Object/Relation impact and must not create Bookmark-specific long-term indexing.
- **F:** Vault/storage/managed-byte preservation and destructive-retirement evidence.
- **G:** caller-zero legacy code deletion only after B and owning product lanes prove parity; CI/developer-workflow health remains G-owned.

## Hotspot / migration rule
Prefer Relation services/domain/tests and avoid broad presentation hotspots. `ObjectSyncService` may receive a patch-sized composition hook when a focused B acceptance explicitly requires production reconciliation. Any schema/migration-changing slice is single-writer and must use the repository hard gate. Do not edit Stage1/People/GenericDatabasePage merely because those workflows produce Relations.

## Validation
Analyze + relevant Relation regressions + full Flutter Test + required `merge-gate` are part of integrity acceptance. Corruption tests should prove no partial mutation and no opportunistic repair. GitHub CI is authoritative when local Flutter execution is unavailable.

## Resume sequence
1. Re-read latest `main`, open B Issues, open PR ownership, shared hotspots and current CI.
2. Re-audit #1042 against the integrated direct-Tag and media-convergence contracts; close/refine it only if every retained saved-URL Relation has an explicit canonical destination with integrity coverage.
3. Continue #1045 only when A/#1044 Person authority is sufficiently integrated for one focused non-overlapping role/group Relation slice; preserve existing Person/Profile Image and legacy compatibility state.
4. If #1042/#1045 are blocked, select another live evidence-backed B integrity slice through the `AGENTS.md` next-work discovery order or stop with the precise dependency/conflict/idle reason.
5. Do not invent Relation abstractions, alternate stores, closure caches, or speculative migrations merely to keep the lane active.

This sequence is not terminal. After every slice/PR/merge, apply the shared Lane continuation and resume/stop contract in `AGENTS.md` before ending the run.
