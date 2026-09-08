# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth; SHAs below are durable checkpoints, not live-state assertions.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**.
- #489 — shared native capabilities: **completed/closed**.
- #495 — MIME/content-aware Image/File import: **completed/closed**.
- #941 — canonical Image preview/editing in shared Object Inspector: **completed/closed** by PR #1002.
- #948 — People/profile imagery migrated to canonical Image/Relation behavior: **completed/closed**.
- #1021 — safe deletion of legacy-Photo-mirrored canonical Images: **completed/closed** by PR #1025, squash merge `271afd42c29dc71a52e58b95ba057287c5b3c38a`.
- #245 — Photo -> Image consolidation umbrella: **open**. No remaining independent D-owned acceptance slice is currently demonstrated. Remaining known gates are Lane G #950 caller-zero cleanup and Lane F #951/#242 real-macOS preservation validation.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open umbrella, product parity established**. The Issue body and #56 routing were refreshed in this run to reflect that the reusable Weblink product/presentation path is integrated and current D audits expose no independent primitive/media defect. Remaining legacy Bookmark URL/thumbnail retirement is Lane G/#225 work unless a concrete primitive correctness gap appears.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation and navigation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is compatibility data/projection only where migration still requires it.
- Canonical Person `Profile Image` Relation is the profile-photo authority; legacy `Person.profilePhotoId` is compatibility data, not a D-owned second identity path.
- Never infer physical-delete authority merely from a Vault-looking path, content hash, or arbitrary stored path.

## Integrated primitive state
### Image / Photo convergence
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media, Bookmark Relation integration, Person profile-image integration, shared Object Inspector composition, and a canonical deletion seam for safely mapped legacy Photo mirrors.

Relevant durable checkpoints:
- #866 completed the canonical content-first Images collection picker and closed #495.
- #869 / #876 routed canonical Image/Weblink media through generic List/Table hosts.
- #881 / #889 / #892 / #901 / #914 / #921 / #930 migrated Bookmark-facing image selection, mutation, reverse lookup, Stage1 filtering/drop, and create flow to canonical Image/Relation authority.
- #895 / PR #922 established strict fail-closed Relation mutation preflight and rollback-safe compatibility projection for Bookmark Image writes.
- #896 / PR #908 established first-run canonical Images masonry Gallery defaults without resetting user View customization.
- #945 / #947 / #948 established canonical Person identity plus Person -> `Profile Image` Relation and People UI migration.
- #981 retired the caller-zero legacy Photo picker.
- #941 / PR #1002 composed canonical Image preview/edit into the shared Inspector while keeping legacy-mirrored edit safety fail-closed.
- #949 / #1015 made canonical `画像` the single normal image collection/navigation surface.
- #1019 retired the caller-zero `PhotoManagementPage` implementation without deleting compatibility data.
- #1021 / PR #1025 made canonical Images the deletion authority for one exact internally consistent legacy Photo mapping.
- G-lane retirement later removed caller-zero Bookmark/AppDatabase Photo update facades and `BookmarkRepository.addPhoto(...)`; current-main checkpoint after #1030 is `a323c3042910421bef3a21b3ec644cfba087379e`.

Legacy `Photos`, `bookmark_photos`, `Person.profilePhotoId`, `photo_object_links` and selected compatibility reads remain intentionally present while caller/migration/preservation requirements still need them. Destructive schema retirement is separate work.

### Weblink convergence
The reusable Weblink product path is established:
- canonical URL identity/normalization and find-or-create reuse;
- Bookmark -> Weblink canonical Relation authority;
- Weblink-owned shared resource metadata and best-effort enrichment;
- managed Representative/Related Image pipeline through canonical Image Objects and Relations;
- real generic Database-host creation/enrichment rather than a Weblink-specific page;
- useful persisted Weblink defaults, including first-use List presentation;
- managed Weblink media rendering through shared generic List/Table/Gallery paths;
- Bookmark visual hosts routed through the shared canonical resolver path, including Stage1 Gallery/List/Table, Notion cards, Bookmark detail visuals, lifecycle rows and reverse lookup;
- People related-Bookmark URL and Bookmark detail URL presentation prefer canonical Bookmark -> Weblink data.

Remaining direct `bookmark.url` / `bookmark.thumbnail` references are not equivalent D work. Current audits classify them as compatibility fallback, read-store transfer, query/search input, import/export, or bridge/update preservation unless a future concrete defect proves otherwise.

## #1021 completion evidence
PR #1025 was squash-merged to `main` as `271afd42c29dc71a52e58b95ba057287c5b3c38a` after Flutter CI #3028 full green.

The deletion seam:
- requires exactly one same-workspace `photo_object_links` mapping and matching persisted legacy identity;
- verifies the legacy Photo path and canonical Image `File` resolve to the same canonical stored-path identity;
- fails closed on malformed/missing/multiple/cross-workspace/mismatched compatibility state;
- deletes the exact legacy Photo row plus canonical Relation-safe Image Object inside one outer Drift transaction;
- retains `RelationMutationService.deleteObject(...)` as the authoritative incoming Relation detach/delete path;
- preserves legacy compatibility cleanup such as `Person.profilePhotoId` clearing;
- evaluates managed-file cleanup only after database mutation and deletes physical bytes only when explicit existing ownership policy proves sole ownership;
- preserves external/shared/ambiguous files and native Images with no legacy mapping;
- keeps raw filesystem/database details out of user-facing delete failures.

Validation: changed-Dart format, guards, Drift generation, Analyze, Flutter Test shards 0/1/2/3, test-health, merge-gate, AI Handoff Audit and AI Migration Lease Audit all passed.

## #155 / #56 audit checkpoint — 2026-09-08
This run re-read current `AGENTS.md`, repository/lane handoffs, #155, #245, #950, #951, latest `main`, open PR ownership and recent Issues.

Findings:
- no open PR currently owns a D hotspot or D-focused implementation;
- broad open-Issue searches for Weblink/Image/File plus source searches for primitive TODO/FIXME markers exposed no new actionable D-owned Issue;
- #155's old 2026-09-05 body still described already-integrated Bookmark visual migration and generic Weblink presentation as unfinished, so it was refreshed to the current architecture and now explicitly routes residual caller-zero compatibility retirement to Lane G/#225;
- #56's live checkpoint similarly marked #155 presentation and #1021 deletion as unfinished, so its cross-lane routing/acceptance was refreshed to record established Weblink product parity and completed #1021;
- #245 already records D complete and leaves the known remaining gates to G #950 and F #951/#242.

Do not turn #155 into speculative persistence or Relation work. Legacy `bookmarks.url` / remote-thumbnail fields should be removed only after production caller-zero and compatibility requirements are proven; behavior-preserving caller-zero retirement belongs to Lane G.

## Exact next actions
1. On the next D run, re-read live #155/#245/#950/#951 state, latest `main`, open PR ownership and CI before editing.
2. Take D work only when a concrete Weblink/Image/File/Tag identity, metadata, content-routing, preview/editing, managed-capability, PDF/File primitive, or Photo -> Image migration defect/requirement exists.
3. Preserve #895/#922 strict Relation preflight for every Bookmark Image writer and preserve #1021 fail-closed mapping/ownership guarantees for Image deletion.
4. Do not duplicate Lane G #950/#225 caller-zero cleanup or Lane F #951/#242 real-machine preservation work.
5. If no independent D-owned work is present, remain idle by design rather than inventing abstractions or deleting compatibility data early.

## Cross-lane dependencies
- Lane B: canonical Relation mutation/read/index/backlink/audit/reconcile remains authoritative; preserve strict preflight for Relation-producing primitive workflows.
- Lane C: generic Database/View/schema UX remains C-owned; Weblink/Image-specific semantics remain D-owned only when primitive-specific.
- Lane G: #950/#225 own behavior-preserving caller-zero legacy Photo/Bookmark compatibility retirement after parity proof.
- Lane F: #951 and #242 own final real-macOS/Vault preservation validation before #245 can close.
- Lane E: owns Search persistence/reconciliation; Lane D emits primitive facts and does not write FTS directly.

## Known risks / boundaries
- Do not delete legacy Photo schema/data merely because replacement UI exists.
- Do not bypass canonical Relation APIs or shared-file edit/delete ownership checks.
- Do not expose raw filesystem paths or implementation exceptions in user-facing Image/File errors.
- Ambiguous/corrupt Photo/Image mapping must fail closed; never silently guess which compatibility row to delete.
- `bookmarks.url` / remote-thumbnail compatibility must not be removed merely because presentation is canonical-first; imports, exports, bridges, search and fallback behavior need caller-zero proof.
- Final Photo -> Image umbrella closure still depends on preservation work outside Lane D.

## Latest run checkpoint / stop reason — 2026-09-08
- Latest audited `main` checkpoint: `a323c3042910421bef3a21b3ec644cfba087379e` after merged G PR #1030.
- #155 and #56 were refreshed directly in GitHub so their live routing no longer advertises already-completed D work.
- No new D-focused Issue, primitive TODO/FIXME, or open PR ownership was found.
- Handoff update branch: `feature/primitives-handoff-155-audit`.
- No shared hotspot lease is held by Lane D.
- Stop reason matches `AGENTS.md`: the active lane has no remaining actionable work. Resume only when live GitHub state exposes a concrete Primitive Objects & Media obligation.
