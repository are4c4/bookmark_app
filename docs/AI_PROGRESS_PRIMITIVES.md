# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth; SHAs below are durable checkpoints, not live-state assertions.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**.
- #489 — shared native capabilities: **completed/closed**.
- #495 — MIME/content-aware Image/File import: **completed/closed**.
- #941 — canonical Image preview/editing in shared Object Inspector: **completed/closed** by PR #1002.
- #245 — Photo -> Image consolidation umbrella: **open**, but no immediate independent D-owned product slice remains after #941. Remaining umbrella gates are primarily Lane C #949 navigation convergence, Lane G #950 caller-zero cleanup, and Lane F #951 preservation validation.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Current production audit finds the major Bookmark visual hosts already behind canonical URL/visual resolvers; continue only when a concrete D-owned primitive/presentation defect is demonstrated rather than deleting compatibility data speculatively.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation and navigation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is compatibility projection only where legacy mapping still requires it.
- Canonical Person `Profile Image` Relation is the profile-photo authority; legacy `Person.profilePhotoId` is compatibility data, not a D-owned second identity path.
- Never infer physical-delete authority merely from a Vault-looking path, content hash, or arbitrary stored path.

## #245 integrated state
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media, Bookmark Relation integration, Person profile-image integration, and shared Object Inspector composition.

Relevant integrated checkpoints:
- #866 completed the canonical content-first Images collection picker and closed #495.
- #869 / #876 routed canonical Image/Weblink media through generic List/Table hosts.
- #881 / #889 / #892 / #901 / #914 / #921 / #930 migrated Bookmark-facing image selection, mutation, reverse lookup, Stage1 filtering/drop, and create flow to canonical Image/Relation authority.
- #895 / PR #922 established strict fail-closed Relation mutation preflight and rollback-safe compatibility projection for Bookmark Image writes.
- #896 / PR #908 established first-run canonical Images masonry Gallery defaults without resetting user View customization.
- #945 / #947 established canonical Person identity and Person -> `Profile Image` Relation.
- #948 / PR #973 moved People profile imagery/mutations to canonical Image/Relation behavior.
- #981 retired the caller-zero legacy Photo picker.
- #941 / PR #1002 composed the existing canonical Image preview/edit panel into `ObjectInspectorPage` only for the system Image ObjectType. Native Images receive safe edit actions, legacy-Photo-mirrored Images preview through canonical managed-file resolution without gaining an edit-safety bypass, metadata refreshes after successful edits, and Image-like custom ObjectTypes do not receive native actions.
- Legacy `Photos`, `bookmark_photos`, `Person.profilePhotoId`, `photo_object_links` and selected compatibility reads remain until caller-zero proof, navigation retirement, preservation validation and any separate destructive-schema decision.

## #941 completion evidence
PR #1002 was squash-merged as `a74abec4cc231af91acbee956b4aaf131be87608` after Flutter CI #2964 full green.

The implementation:
- reuses `ObjectImageDetailPanel`, `CanonicalImageEditService.fromStores(...)`, the active path resolver, and `ObjectStore` rather than creating a second Image edit path;
- refreshes surrounding Inspector metadata after edits;
- keeps user-visible reload/edit errors privacy-safe;
- preserves File detail, Properties, Relations, Body and Daily Note behavior;
- includes focused native/legacy/custom Image Inspector integration coverage;
- replaces global `pumpAndSettle()` assumptions with bounded state-specific waits where asynchronous Image preview state can remain active;
- keeps the universal Body regression viewport-independent after the Image panel increased canonical Image Inspector height.

Validation for #1002 / CI #2964:
- changed-Dart format: pass;
- shared-hotspot / maintainability / legacy-dependency / presentation-error privacy guards: pass;
- Drift generation: pass;
- Analyze: pass;
- Flutter Test shards 0/1/2/3: pass;
- test-health and merge-gate: pass;
- AI Handoff Audit on the implementation head: pass.

## #155 audit checkpoint
A fresh production audit after #941 found the main Bookmark presentation hosts already use shared canonical resolvers:
- Notion cards, lifecycle rows, reverse lookup, Bookmark detail, and Stage1 List/Table/Gallery consume `BookmarkVisualImage` / `BookmarkVisualResolver` paths;
- People-related Bookmark URL presentation already resolves canonical Bookmark -> Weblink URL first;
- remaining direct `bookmark.url` / `bookmark.thumbnail` references are largely compatibility fallback, read-store transfer, query/search input, export, or bridge/update compatibility and must be classified before removal.

Do not turn #155 into speculative persistence or Relation work. Legacy `bookmarks.url` / remote-thumbnail fields should be deleted only after production caller-zero and compatibility requirements are proven, coordinated with Lane G where the work is behavior-preserving retirement.

## Exact next actions
1. Re-read live #245/#949/#950/#951 state before taking more Photo -> Image work. Do not duplicate Lane C navigation retirement or Lane G caller-zero cleanup.
2. Re-audit #155 only when current code exposes a concrete Weblink/Image primitive or presentation gap. Prefer canonical resolver reuse; do not add another Weblink persistence/media path.
3. Preserve #895/#922 strict Relation preflight for every Bookmark Image writer and existing shared-file edit/delete ownership checks.
4. After Lane C retires the legacy `写真` navigation, re-audit remaining D-owned production Photo behavior. Any code deletion with proven caller-zero belongs to Lane G unless primitive semantics themselves need correction.
5. If no independent D-owned work is found, remain idle by design rather than inventing abstractions or deleting compatibility data early.

## Cross-lane dependencies
- Lane B: preserve #895/#922 strict Relation mutation preflight for every Bookmark Image writer.
- Lane C: #949 owns making canonical `Images` the single normal user-facing collection/navigation surface; #941 is no longer a blocker.
- Lane G: #950 owns behavior-preserving caller-zero legacy Photo cleanup after product parity.
- Lane F: #951 owns final real-macOS/Vault preservation validation before #245 can close.
- Lane E: owns Search persistence/reconciliation; Lane D emits primitive facts and does not write FTS directly.

## Known risks / boundaries
- Do not delete legacy Photo schema/data merely because replacement UI exists.
- Do not bypass canonical Relation APIs or shared-file edit/delete ownership checks.
- Do not expose raw filesystem paths or exceptions in user-facing Image/File errors.
- Legacy Photo mirrors may preview through canonical Image resolution but must not gain an edit-safety bypass.
- `bookmarks.url` / remote-thumbnail compatibility must not be removed merely because current presentation is canonical-first; imports, exports, bridges and fallback behavior need caller-zero proof.

## Previous run stop reason
#941 is complete and merged. The next #245 actions are owned by Lane C/G/F, while the current #155 audit did not expose a concrete independent D-owned defect. Lane D should resume when live GitHub state shows a new primitive/media obligation or when downstream Photo -> Image convergence exposes a D-owned gap.
