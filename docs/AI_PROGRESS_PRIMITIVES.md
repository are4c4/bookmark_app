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

## Active focused issue

### #1054 — direct canonical Weblink capture
Goal: provide a narrow capture boundary that normalizes an incoming URL and creates/reuses the canonical Weblink Object without creating a new permanent Bookmark row/Object authority.

Acceptance:
- equivalent normalized URLs reuse one canonical Weblink identity;
- new generic capture does not require/create permanent Bookmark authority;
- normalization/collision failures fail closed without duplicate canonical targets;
- restart/reconciliation proves reuse;
- metadata/enrichment remains separable from identity transaction;
- API is reusable by Inbox/share-sheet/command-palette callers;
- no Stage1 retirement, semantic Paper/Book inference or destructive Bookmark migration in this slice.

## Conditional umbrellas
- **#155** — Weblink native identity/normalization/metadata/media. Historical wording that describes Bookmark as a permanent user-context Object is superseded by `docs/product_architecture.md`/#1039/#1048.
- **#245** — Photo→Image convergence. Product-facing Image authority is canonical; remaining legacy schema/data stays for compatibility/preservation until explicit retirement gates are satisfied.

## Integrated native-capability foundation
### Weblink
- normalized canonical URL identity and find-or-create reuse;
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
- **B:** all Relation lifecycle/integrity, including Weblink/Image relations.
- **C:** generic Database/View/schema/query UX.
- **E:** Search projection/indexing; D produces native facts but does not write FTS directly.
- **F:** Vault/filesystem lifecycle, portable path and physical-delete ownership.
- **G:** caller-zero legacy Bookmark/Photo code retirement after parity; D must not delete compatibility simply because canonical presentation exists.

## Known risks
- never infer physical-delete authority from path/hash alone;
- do not silently merge multiple legacy Bookmark contexts merely because they normalize to one Weblink;
- preserve canonical Relation preflight for media-producing workflows;
- do not create a Weblink-specific page/persistence engine when generic Object/Database/View contracts suffice;
- do not reclassify Tag as a native primitive.

## Validation
Changed-Dart format, Analyze, full Flutter Test and focused normalization/restart/collision regressions are required for #1054. Media changes also require ownership/rollback safety tests where files are created or deleted.

## Resume sequence
1. re-read #1054 and current main/open PRs;
2. implement only the narrow canonical Weblink capture identity boundary first;
3. keep enrichment best-effort and outside identity correctness where practical;
4. add reuse/collision/restart regressions;
5. update this handoff with durable branch/commit/PR facts;
6. take #155/#245 work only when a concrete native-capability defect remains after #1054.