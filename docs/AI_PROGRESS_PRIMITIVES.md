# AI Progress — Primitive Objects & Media Lane

> Durable Lane D handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Own irreducible native behavior for Weblink, Image and File Objects: identity, normalization, metadata/enrichment, MIME/content routing, managed-media capability and primitive-specific preview/editing. Do not create parallel persistence systems for common semantic domains.

## Architecture correction
- Weblink, Image and File are Objects with native capabilities.
- `Bookmark` is not a final ObjectType. Normal URL capture creates/reuses a Weblink Object directly.
- **Tag/TagGroup are generic ObjectTypes, not native D primitives.** Tag Object-core prerequisites route to A, hierarchy integrity to B, hierarchy-aware query/picker UX to C.
- PDF is a capability of File, not a separate persistent ObjectType/table/search domain.
- Lane F owns Vault/filesystem byte placement and physical-delete/export path policy; D owns primitive Object identity/product semantics and persists native provenance supplied by trusted storage boundaries.

## Current state
Lane D has no active focused runtime implementation Issue after completion of #1275. Continue only when live GitHub exposes a concrete Weblink/Image/File native-capability defect or an explicit D-owned prerequisite for another lane. Do not manufacture work from completed umbrellas or take downstream Relation, Database/View, Vault/export or legacy caller-zero responsibilities.

Cross-lane integration checkpoints now on `main`:
- B/#1103 is implemented through PR #1117; Relation Weblink quick-create uses `CanonicalWeblinkCaptureService` and no longer owns a weaker production `WeblinkObjectService.findOrCreate` identity path.
- F/#1146 is implemented through PR #1159; portable Image-byte export consumes the explicit managed-file ownership provenance emitted by D/#1141 without inferring ownership from path location.
- B/#1154 is implemented through PR #1176; retained Bookmark `Images` / `Cover Image` compatibility state converges onto canonical Weblink `Related images` / `Representative image` Relations while reusing the existing D-owned Weblink/Image native schema and leaving preview/download behavior and managed-byte ownership unchanged.
- F/#1268 is implemented through PR #1282; durable history treats D-persisted ownership as provenance input only. F forms a Vault-relative managed-byte identity from explicit ownership plus relative path, keeps external absolute references metadata-only, requires a retained-history claim plus verified byte presence before reporting historical bytes as restorable, and keeps GC/physical-delete authority behind F-owned reference and filesystem safety checks.

These integrations validate the existing D boundaries; they do not create new D work by themselves.

## Most recent focused completion

### #1275 — keep explicit Image ownership correlated with the persisted File
PR #1279 tightened the #1141 provenance contract after a service-level correctness audit found a source-only reuse edge case:
- `ImageObjectService.findOrCreateManaged(...)` may still reuse an Image by canonical Source URL or File identity;
- trusted managed ownership may fill previously missing ownership only when the persisted File is empty and can adopt the incoming managed path, or when the persisted File already matches that incoming canonical path;
- when reuse is only by Source URL, the existing File is non-empty and different, and the caller asserts trusted ownership for the incoming managed copy, the service fails closed before any File/Source/ownership mutation;
- source-only reuse without a new ownership assertion keeps the established non-destructive reuse behavior;
- existing non-empty ownership remains immutable and is never overwritten by retries;
- no duplicate Image is manufactured on the fail-closed path;
- ownership is still never inferred from path location and no historical/bulk ownership backfill is performed;
- no schemaVersion/migration, Relation change, Image identity redesign, F export/delete policy change or filesystem policy change was introduced.

The latest-main synchronized implementation passed changed-Dart formatting, Analyze, all four Flutter Test shards, `test-health` and required `merge-gate`. #1275 is completed on `main` through #1279.

### #1141 — explicit managed-file ownership provenance for Image
PR #1143 completed the D-side producer contract required by the portable-export filesystem boundary:
- canonical Image defines one hidden system `Storage ownership` Property using the shared closed `ManagedFileOwnership` storage-key contract;
- `ImageObjectService.findOrCreateManaged(...)` accepts optional explicit ownership, persists it only when supplied by a trusted caller and never infers ownership from a path;
- reuse may fill previously missing ownership only from a later explicit trusted managed-copy operation, subject to the #1275 requirement that that provenance remains correlated with the persisted File;
- existing non-empty ownership metadata is preserved rather than overwritten by retries;
- generic managed Image creation threads the typed ownership value without introducing another provenance store;
- trusted local Image import and Weblink preview managed-copy workflows emit `vault-managed-copy-v1` only after the managed storage boundary creates/reuses the bytes;
- direct/legacy Image creation without explicit ownership remains unowned, including historical paths under `photos/...`;
- user-customized Image default Property ordering remains preserved while known generated defaults may add the hidden metadata Property;
- no historical bulk backfill, Drift schemaVersion migration, Relation redesign, Image→File redesign, destructive rewrite or F portable-export/path-policy change was introduced.

F/#1146 subsequently consumed this producer contract successfully on `main`: D supplies explicit provenance, while F decides whether an owned Image reference is safe/eligible for portable byte inclusion under its filesystem contract. F/#1268 further established that the same provenance does not itself promise durable-history byte retention or restoreability; those claims require F-owned retention state and verified byte presence.

### #1054 — direct canonical Weblink capture
The canonical URL-capture contract is explicit and independent of permanent Bookmark authority:
- `CanonicalWeblinkCaptureService` validates/normalizes before mutation and serializes first-use definition initialization plus identity resolution;
- equivalent URLs reuse exactly one canonical Weblink Object, including concurrent first capture and capture after database restart;
- pre-existing multiple Weblinks that normalize to the same URL fail closed instead of selecting or manufacturing a target;
- normal generic Database URL creation, legacy Bookmark reconciliation and URL Value promotion use the same D-owned identity boundary;
- optional metadata/enrichment remains after identity establishment and fail-soft;
- direct generic capture creates no Bookmark row/Object authority;
- reconciliation collision preserves mirrored Bookmark URL state and legacy `bookmarks.url`, creates no Relation and creates no third Weblink target;
- malformed unrelated historical Weblink values remain preserved rather than repaired as a side effect of valid capture.

B/#1103 subsequently adopted this same boundary in Relation target quick-create through PR #1117. Current `main` therefore has the canonical capture boundary in the generic capture/reconciliation paths and in Relation Weblink quick-create; future convenience callers must not reintroduce a direct weaker production identity path.

## Conditional umbrellas
- **#155** — Weblink native identity/normalization/metadata/media. The D-owned native foundation and direct-capture slice are complete. Remaining open acceptance is Bookmark migration/parity/retirement work routed to A/B/C/G unless a new concrete Weblink native-capability defect is demonstrated.
- **#245** — Photo→Image convergence is completed as an umbrella. Product-facing Image authority is canonical; remaining compatibility/preservation work belongs to its owning lane unless a new concrete Image primitive defect is discovered. #1141 and #1275 were focused post-completion Image provenance defects and did not reopen Photo→Image migration broadly.

## Integrated native-capability foundation
### Weblink
- normalized canonical URL identity and collision-safe direct capture/reuse;
- concurrent first capture and restart identity reuse;
- Weblink-owned metadata/enrichment;
- Representative/Related Image Relations using canonical Image Objects;
- generic Database-host creation/enrichment and shared media rendering;
- Relation target quick-create uses the same canonical capture identity boundary;
- retained Bookmark media compatibility can converge through B-owned canonical Weblink Image Relations without changing D native identity/media behavior;
- legacy Bookmark URL/thumbnail remains compatibility input only where still required.

### Image
- canonical managed Image import/create/reuse, provenance and geometry;
- explicit closed managed-file ownership metadata when a trusted producer proves byte ownership; path location alone remains non-authoritative;
- trusted ownership remains correlated with the persisted File: source-only reuse cannot attach ownership for a different incoming managed path to an existing non-empty File;
- content-first Image/File classification;
- preview/edit/rotate/flip/restore/crop behavior;
- canonical Relation integration for Bookmark Images/Cover and Person Profile Image;
- canonical Images normal collection/navigation and safe deletion of exact legacy Photo mirrors;
- portable export can consume explicitly owned Image bytes through the F-owned filesystem contract;
- durable history may use explicit ownership as provenance input, but retention/restorability still requires F-owned retained-history claims and verified managed-byte presence;
- ambiguous/shared/external file ownership remains fail-closed/preserved.

### File
- canonical File primitive with managed/external path semantics;
- MIME/content routing and preview/extracted-text producer behavior;
- explicit managed-file ownership provenance through the same closed storage-key contract;
- managed byte placement/deletion/export/history-retention eligibility delegated to Lane F contracts.

## Cross-lane boundaries
- **A:** generic Object/ObjectType/lifecycle/Body and migration authority when no native primitive semantics are involved.
- **B:** all Relation lifecycle/integrity. #1103 and #1154 are integrated checkpoints proving B consumes canonical D Weblink/Image boundaries for quick-create and saved-URL media convergence without redesigning native identity, schema, preview/download or byte ownership.
- **C:** generic Database/View/schema/query/capture-host UX, including Stage1 replacement work such as #1043.
- **E:** Search projection/indexing; D produces native facts but does not write FTS directly.
- **F:** Vault/filesystem lifecycle, portable path, export packaging, durable-history byte retention/restoreability and physical-delete eligibility. #1146 consumes D/#1141 ownership provenance for export; #1268 consumes explicit ownership plus Vault-relative identity for history retention while keeping external references metadata-only. D must not broaden F path/retention/GC policy or infer eligibility from path location.
- **G:** caller-zero legacy Bookmark/Photo code retirement after parity; D must not delete compatibility simply because canonical presentation exists.

## Known risks
- never infer physical-delete/export authority from path/hash alone;
- do not treat persisted managed ownership by itself as a promise that a historical Image/File byte is retained or restorable;
- do not backfill Image ownership solely because an old path happens to be under the active Vault/profile;
- do not attach incoming trusted Image ownership through Source URL reuse when the persisted non-empty File identifies different bytes; fail closed before mutation instead;
- do not silently merge multiple legacy Bookmark contexts merely because they normalize to one Weblink;
- preserve canonical Relation preflight for media-producing workflows;
- do not create a Weblink-specific page/persistence engine when generic Object/Database/View contracts suffice;
- do not reclassify Tag as a native primitive;
- do not let convenience callers bypass the canonical Weblink capture boundary and reintroduce ambiguous collision selection.

## Validation expectations
For future D runtime changes, changed-Dart format, Analyze and full Flutter Test remain required. Media changes additionally need focused preservation/rollback regressions when bytes are created, mutated or deleted. Native ownership changes must continue to prove explicit provenance, File/provenance correlation and rejection of path-based inference.

## Resume sequence
1. re-read current `main`, open Issues/PRs, `AGENTS.md`, architecture/repository handoffs and this file;
2. re-audit #155 plus newly reported Weblink/Image/File native-capability defects;
3. treat #245 as completed unless another concrete Image primitive defect is demonstrated;
4. treat B/#1103, B/#1154, F/#1146 and F/#1268 as completed integration checkpoints, not work to reopen; do not take C #1043 or other Database/View UX, B's remaining Relation migration work, F export/path/history-retention policy, or G legacy caller-zero cleanup;
5. if a concrete D-owned defect or prerequisite exists, use/open one focused Issue and implement the smallest preservation-safe slice;
6. otherwise stop with `idle-no-work` after the live final resume audit required by `AGENTS.md`.

This sequence is not terminal. After any future slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane D continues only through concrete native-capability obligations.

Stop reason: idle-no-work — #1275 is completed on main through #1279 and the Image ownership contract now fails closed when trusted provenance would target a different persisted File; #1141 remains completed; B/#1103 canonical quick-create adoption is integrated through #1117; B/#1154 Bookmark-media convergence is integrated through #1176; F/#1146 Image-byte export consumption is integrated through #1159; F/#1268 managed-byte history retention is integrated through #1282 without adding D runtime ownership; #245 remains completed; #155 has no remaining D-owned acceptance beyond newly demonstrated native defects; the live open-PR audit found no D runtime implementation owner; the live open-Issue audit found no independent D-primary Weblink/Image/File runtime work; remaining Weblink/Image migration consumers are routed to A/B/C/G. No D shared-hotspot or migration-writer work is currently required.
