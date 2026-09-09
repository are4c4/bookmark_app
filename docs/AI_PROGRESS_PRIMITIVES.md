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

## Active focused issue

### #1141 — explicit managed-file ownership provenance for Image
Portable export/filesystem policy now requires explicit ownership evidence and intentionally refuses to infer physical-byte ownership from path location. Canonical File already persists the closed `ManagedFileOwnership` contract, while canonical Image previously stored managed File/source/geometry metadata without equivalent ownership provenance.

Lane D therefore owns the producer-side correction only:
- canonical Image defines one hidden system `Storage ownership` Property using the shared closed `ManagedFileOwnership` storage key contract;
- `ImageObjectService.findOrCreateManaged(...)` accepts optional explicit ownership, fills it only when supplied, and never manufactures ownership from a path;
- existing non-empty ownership metadata wins over later retries; missing metadata may be filled only by a later trusted managed-copy operation proving the same canonical Image identity;
- generic Image creation threads the typed ownership value without introducing another provenance store;
- trusted local Image import and Weblink preview managed-copy flows supply `vault-managed-copy-v1` after they create/reuse app-managed bytes;
- legacy Photo/Image reconciliation and direct Image creation remain unowned unless an explicit trusted producer supplies ownership;
- no historical bulk backfill, Drift schemaVersion migration, Relation redesign, Image→File redesign, or F portable-export/path-policy change belongs in this slice.

The F boundary remains fail closed: D persists provenance; F decides whether a persisted owned reference is actually eligible for export/delete according to its filesystem/path contract.

## Most recent focused completion

### #1054 — direct canonical Weblink capture
The canonical URL-capture contract is now explicit and independent of permanent Bookmark authority:
- `CanonicalWeblinkCaptureService` validates/normalizes before mutation and serializes first-use definition initialization plus identity resolution;
- equivalent URLs reuse exactly one canonical Weblink Object, including first concurrent captures and capture after database restart;
- pre-existing multiple Weblinks that normalize to the same URL fail closed instead of selecting or manufacturing a target;
- normal generic Database URL creation, legacy Bookmark reconciliation and URL Value promotion use the same D-owned identity boundary;
- optional metadata/enrichment remains after identity establishment and fail-soft;
- direct generic capture creates no Bookmark row/Object authority;
- reconciliation collision preserves mirrored Bookmark URL state and legacy `bookmarks.url`, creates no Relation and creates no third Weblink target;
- malformed unrelated historical Weblink values remain preserved rather than repaired as a side effect of valid capture.

The boundary is intentionally narrow so future Inbox/share-sheet/command-palette hosts can consume canonical Weblink identity without acquiring Bookmark semantics.

A remaining direct `WeblinkObjectService.findOrCreate` production caller exists in Relation target quick-create. That caller is Lane B ownership and must adopt the canonical capture boundary there rather than being modified by Lane D or used to justify a second Weblink identity path.

## Conditional umbrellas
- **#155** — Weblink native identity/normalization/metadata/media. Historical wording that describes Bookmark as a permanent user-context Object is superseded by `docs/product_architecture.md`/#1039/#1048. After #1054, take new D work only for a concrete Weblink native-capability defect.
- **#245** — Photo→Image convergence is completed as an umbrella. Product-facing Image authority is canonical; any remaining compatibility/preservation work belongs to its owning lane unless a new concrete Image primitive defect is discovered. #1141 is such a concrete post-completion native provenance defect and does not reopen Photo→Image migration broadly.

## Integrated native-capability foundation
### Weblink
- normalized canonical URL identity and collision-safe direct capture/reuse;
- concurrent first capture and restart identity reuse;
- Weblink-owned metadata/enrichment;
- Representative/Related Image Relations using canonical Image Objects;
- generic Database-host creation/enrichment and shared media rendering;
- legacy Bookmark URL/thumbnail remains compatibility input only where still required.

### Image
- canonical managed Image import/create/reuse, provenance and geometry;
- explicit closed managed-file ownership metadata when a trusted producer proves byte ownership; path location alone remains non-authoritative;
- content-first Image/File classification;
- preview/edit/rotate/flip/restore/crop behavior;
- canonical Relation integration for Bookmark Images/Cover and Person Profile Image;
- canonical Images normal collection/navigation and safe deletion of exact legacy Photo mirrors;
- ambiguous/shared/external file ownership remains fail-closed/preserved.

### File
- canonical File primitive with managed/external path semantics;
- MIME/content routing and preview/extracted-text producer behavior;
- explicit managed-file ownership provenance through the same closed storage-key contract;
- managed byte placement/deletion authority delegated to Lane F contracts.

## Cross-lane boundaries
- **A:** generic Object/ObjectType/lifecycle/Body and migration authority when no native primitive semantics are involved.
- **B:** all Relation lifecycle/integrity, including Weblink/Image relations and Relation target quick-create adoption of canonical Weblink capture.
- **C:** generic Database/View/schema/query UX.
- **E:** Search projection/indexing; D produces native facts but does not write FTS directly.
- **F:** Vault/filesystem lifecycle, portable path, export packaging and physical-delete eligibility. D may persist explicit native ownership provenance but must not broaden F path policy or infer eligibility from `photos/...`.
- **G:** caller-zero legacy Bookmark/Photo code retirement after parity; D must not delete compatibility simply because canonical presentation exists.

## Known risks
- never infer physical-delete/export authority from path/hash alone;
- do not backfill Image ownership solely because an old path happens to be under the active Vault/profile;
- do not silently merge multiple legacy Bookmark contexts merely because they normalize to one Weblink;
- preserve canonical Relation preflight for media-producing workflows;
- do not create a Weblink-specific page/persistence engine when generic Object/Database/View contracts suffice;
- do not reclassify Tag as a native primitive;
- do not let convenience callers bypass the canonical Weblink capture boundary and reintroduce ambiguous collision selection.

## Validation
Changed-Dart format, Analyze and full Flutter Test are required. #1141 additionally requires focused regressions proving: explicit ownership persistence; no path-based inference when ownership is omitted; trusted reuse can fill missing ownership; existing non-empty ownership is preserved; local Image import and Weblink preview managed-copy flows emit the closed ownership key. Media changes also require rollback/preservation safety where files are created or deleted.

## Resume sequence
1. re-read current main/open Issues/PRs and this handoff;
2. while #1141 is open, complete the smallest D-owned ownership-provenance slice and validate it without changing F export/path policy;
3. after #1141 lands, re-audit #155 and newly reported Weblink/Image/File native-capability defects;
4. treat #245 as completed unless another concrete Image primitive defect is demonstrated;
5. do not take Lane B Relation quick-create work, Lane C capture-host UX, F packaging/path policy, or G legacy caller-zero cleanup;
6. if another concrete D-owned Weblink/Image/File defect exists, open/use one focused Issue and implement the smallest preservation-safe slice;
7. otherwise stop with `idle-no-work` and live evidence that no independent D-native obligation remains.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane D continues only through concrete native-capability obligations; it must not manufacture work from already-completed umbrellas or steal another lane's remaining caller.

Stop reason: active-work — #1141 is the current D-owned focused Image provenance defect. Complete and validate it before reassessing `idle-no-work`.
