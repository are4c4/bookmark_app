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
- #245 — Photo -> Image consolidation umbrella: **open**. The current live audit finds no remaining independent D-owned acceptance slice after #1021. Remaining gates are primarily Lane G #950 caller-zero cleanup and Lane F #951/#242 real-macOS preservation validation.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Current production audits have not exposed a new concrete D-owned primitive/media correctness gap; resume only for demonstrated Weblink/Image/File identity, metadata, enrichment, media, preview/editing or migration work.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation and navigation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is compatibility data/projection only where migration still requires it.
- Canonical Person `Profile Image` Relation is the profile-photo authority; legacy `Person.profilePhotoId` is compatibility data, not a D-owned second identity path.
- Never infer physical-delete authority merely from a Vault-looking path, content hash, or arbitrary stored path.

## #245 integrated state
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media, Bookmark Relation integration, Person profile-image integration, shared Object Inspector composition, and a canonical deletion seam for safely mapped legacy Photo mirrors.

Relevant integrated checkpoints:
- #866 completed the canonical content-first Images collection picker and closed #495.
- #869 / #876 routed canonical Image/Weblink media through generic List/Table hosts.
- #881 / #889 / #892 / #901 / #914 / #921 / #930 migrated Bookmark-facing image selection, mutation, reverse lookup, Stage1 filtering/drop, and create flow to canonical Image/Relation authority.
- #895 / PR #922 established strict fail-closed Relation mutation preflight and rollback-safe compatibility projection for Bookmark Image writes.
- #896 / PR #908 established first-run canonical Images masonry Gallery defaults without resetting user View customization.
- #945 / #947 established canonical Person identity and Person -> `Profile Image` Relation.
- #948 / PR #973 moved People profile imagery/mutations to canonical Image/Relation behavior.
- #981 retired the caller-zero legacy Photo picker.
- #941 / PR #1002 composed canonical Image preview/edit into the shared Inspector while keeping legacy-mirrored edit safety fail-closed.
- #949 / #1015 made canonical `画像` the single normal image collection/navigation surface.
- #1019 retired the caller-zero `PhotoManagementPage` implementation without deleting compatibility data.
- #1021 / PR #1025 made canonical Images the deletion authority for one exact internally consistent legacy Photo mapping.
- Legacy `Photos`, `bookmark_photos`, `Person.profilePhotoId`, `photo_object_links` and selected compatibility reads remain intentionally present while caller/migration/preservation requirements still need them. Destructive schema retirement is separate work.

## #1021 completion checkpoint
Implementation branch: `feature/primitives-legacy-image-delete-1021`.

PR #1025 was squash-merged to `main` as `271afd42c29dc71a52e58b95ba057287c5b3c38a` after Flutter CI #3028 full green.

The deletion seam now:
- preflights the canonical Image and requires exactly one same-workspace `photo_object_links` mapping;
- rejects malformed/missing/multiple/cross-workspace mapping state and mismatched persisted `Legacy Photo ID` values;
- verifies the mapped legacy Photo path and canonical Image `File` resolve to the same canonical stored-path identity before destructive mutation;
- deletes the exact legacy Photo compatibility row and canonical Relation-safe Image Object inside one outer Drift transaction, preventing a surviving Photo from re-promoting after a partial delete;
- retains `RelationMutationService.deleteObject(...)` as the authoritative incoming Relation detach/delete path;
- preserves legacy Photo deletion semantics including `Person.profilePhotoId` clearing and compatibility cascades;
- evaluates managed-file cleanup only after the Photo row is removed, and physically deletes only after the DB transaction succeeds and the existing ownership policy proves the managed file is solely owned;
- preserves external/shared/ambiguous files and native Images with no legacy mapping;
- keeps raw filesystem/database details out of user-facing delete failures.

Focused regression coverage includes bridge-owned legacy mirrors, pre-existing native Images reused by Photo promotion, Legacy Photo ID mismatch, canonical file-identity mismatch, Relation/backlink detachment, legacy Person profile-photo clearing, native Image deletion, managed/shared/external-file preservation and managed-directory symlink safety.

Validation for PR #1025 / Flutter CI #3028 on head `e92e4d82b6ffcc11091db6a1432281ce083dec41`:
- changed-Dart format: pass;
- shared-hotspot / maintainability / legacy-dependency / presentation-error privacy guards: pass;
- Drift generation: pass;
- Analyze: pass;
- Flutter Test shards 0/1/2/3: pass;
- test-health: pass;
- merge-gate: pass;
- AI Handoff Audit #61: pass;
- AI Migration Lease Audit #43: pass.

## #155 audit checkpoint
Production audits around the current canonical architecture found the major Bookmark presentation hosts already use shared canonical URL/visual resolvers:
- Notion cards, lifecycle rows, reverse lookup, Bookmark detail, and Stage1 List/Table/Gallery consume canonical visual resolver paths;
- People-related Bookmark URL presentation resolves canonical Bookmark -> Weblink URL first;
- remaining direct `bookmark.url` / `bookmark.thumbnail` references are compatibility fallback, read-store transfer, query/search input, export, or bridge/update compatibility and must be classified before removal.

Do not turn #155 into speculative persistence or Relation work. Legacy `bookmarks.url` / remote-thumbnail fields should be removed only after production caller-zero and compatibility requirements are proven; behavior-preserving caller-zero retirement belongs to Lane G.

## Exact next actions
1. On the next D run, re-read live #155/#245/#950/#951 state, latest `main`, open PR ownership and CI before editing.
2. Take D work only when a concrete Weblink/Image/File/Tag identity, metadata, content-routing, preview/editing, managed-capability, or Photo -> Image migration defect/requirement exists.
3. Preserve #895/#922 strict Relation preflight for every Bookmark Image writer and preserve #1021 fail-closed mapping/ownership guarantees for Image deletion.
4. Do not duplicate Lane G #950 caller-zero cleanup or Lane F #951/#242 real-machine preservation work.
5. If no independent D-owned work is present, remain idle by design rather than inventing abstractions or deleting compatibility data early.

## Cross-lane dependencies
- Lane B: canonical Relation mutation/read/index/backlink/audit/reconcile remains authoritative; preserve strict preflight for Relation-producing Image workflows.
- Lane C: canonical Images navigation/presentation convergence is integrated; generic Database/View/schema UX remains C-owned.
- Lane G: #950 owns behavior-preserving caller-zero legacy Photo/Bookmark compatibility retirement after parity proof.
- Lane F: #951 and #242 own final real-macOS/Vault preservation validation before #245 can close.
- Lane E: owns Search persistence/reconciliation; Lane D emits primitive facts and does not write FTS directly.

## Known risks / boundaries
- Do not delete legacy Photo schema/data merely because replacement UI exists.
- Do not bypass canonical Relation APIs or shared-file edit/delete ownership checks.
- Do not expose raw filesystem paths or implementation exceptions in user-facing Image/File errors.
- Ambiguous/corrupt Photo/Image mapping must fail closed; never silently guess which compatibility row to delete.
- `bookmarks.url` / remote-thumbnail compatibility must not be removed merely because presentation is canonical-first; imports, exports, bridges and fallback behavior need caller-zero proof.
- Final Photo -> Image umbrella closure still depends on preservation work outside Lane D.

## Latest run checkpoint / stop reason — 2026-09-08
- Active implementation Issue #1021 is completed/closed.
- PR #1025 is integrated on `main` as `271afd42c29dc71a52e58b95ba057287c5b3c38a` with full CI/audit green.
- Post-merge live D audit found no remaining actionable independent D-owned Issue. #245's remaining gates are Lane G #950 and Lane F #951/#242; #155 exposes no demonstrated new D-owned defect in the current audit.
- Handoff update branch: `feature/primitives-handoff-1021`.
- No shared hotspot lease is held by Lane D.
- Stop reason matches `AGENTS.md`: the active lane has no remaining actionable work. Resume only when live GitHub state exposes a concrete Primitive Objects & Media obligation.
