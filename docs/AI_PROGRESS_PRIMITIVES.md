# AI Progress — Primitive Objects & Media Lane

> Durable Lane D handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Own irreducible native behavior for Weblink, Image and File Objects: identity, normalization, metadata/enrichment, MIME/content routing, managed-media capability and primitive-specific preview/editing. Do not create parallel persistence systems for common semantic domains.

## Architecture correction
- Weblink, Image and File are Objects with native capabilities.
- `Bookmark` is not a final ObjectType. Normal URL capture creates/reuses a Weblink Object directly.
- **Tag/TagGroup are generic ObjectTypes, not native D primitives.** Tag Object-core prerequisites route to A, hierarchy integrity to B, hierarchy-aware query/picker UX to C.
- PDF is a capability of File, not a separate persistent ObjectType/table/search domain.
- Lane F owns Vault/filesystem byte placement and physical-delete ownership; D owns primitive Object identity/product semantics.

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
- **#245** — Photo→Image convergence is completed as an umbrella. Product-facing Image authority is canonical; any remaining compatibility/preservation work belongs to its owning lane unless a new concrete Image primitive defect is discovered.

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
- content-first Image/File classification;
- preview/edit/rotate/flip/restore/crop behavior;
- canonical Relation integration for Bookmark Images/Cover and Person Profile Image;
- canonical Images normal collection/navigation and safe deletion of exact legacy Photo mirrors;
- ambiguous/shared/external file ownership remains fail-closed/preserved.

### File
- canonical File primitive with managed/external path semantics;
- MIME/content routing and preview/extracted-text producer behavior;
- managed byte placement/deletion authority delegated to Lane F contracts.

## Cross-lane boundaries
- **A:** generic Object/ObjectType/lifecycle/Body and migration authority when no native primitive semantics are involved.
- **B:** all Relation lifecycle/integrity, including Weblink/Image relations and Relation target quick-create adoption of canonical Weblink capture.
- **C:** generic Database/View/schema/query UX.
- **E:** Search projection/indexing; D produces native facts but does not write FTS directly.
- **F:** Vault/filesystem lifecycle, portable path and physical-delete ownership.
- **G:** caller-zero legacy Bookmark/Photo code retirement after parity; D must not delete compatibility simply because canonical presentation exists.

## Known risks
- never infer physical-delete authority from path/hash alone;
- do not silently merge multiple legacy Bookmark contexts merely because they normalize to one Weblink;
- preserve canonical Relation preflight for media-producing workflows;
- do not create a Weblink-specific page/persistence engine when generic Object/Database/View contracts suffice;
- do not reclassify Tag as a native primitive;
- do not let convenience callers bypass the canonical Weblink capture boundary and reintroduce ambiguous collision selection.

## Validation
Changed-Dart format, Analyze, full Flutter Test and focused normalization/reuse/concurrency/restart/collision/preservation regressions are required for the #1054 contract. Media changes also require ownership/rollback safety tests where files are created or deleted.

## Resume sequence
1. re-read current main/open Issues/PRs and this handoff;
2. re-audit #155 and newly reported Weblink native-capability defects;
3. treat #245 as completed unless a new concrete Image primitive defect is demonstrated;
4. do not take Lane B Relation quick-create work, Lane C capture-host UX, or G legacy caller-zero cleanup;
5. if a concrete D-owned Weblink/Image/File defect exists, open/use one focused Issue and implement the smallest preservation-safe slice;
6. otherwise stop with `idle-no-work` and the live evidence that no independent D-native obligation remains.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane D continues only through concrete native-capability obligations; it must not manufacture work from already-completed umbrellas or steal another lane's remaining caller.

Stop reason: idle-no-work — #1054 is completed on main; #245 is completed; #155 has no remaining D-owned acceptance beyond newly demonstrated native defects; live open-Issue/PR audit found no independent D Weblink/Image/File focused work; the remaining direct Weblink `findOrCreate` production bypass is Relation target quick-create and is routed to Lane B in #1103.