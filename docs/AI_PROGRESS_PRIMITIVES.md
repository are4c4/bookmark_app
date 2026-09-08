# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth; SHAs below are checkpoints only.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**.
- #489 — shared native capabilities: **completed/closed**.
- #495 — MIME/content-aware Image/File import: **completed/closed**.
- #245 — Photo -> Image consolidation umbrella: **open**. Canonical Image, Bookmark-facing migration, canonical Person/Profile Image migration, and legacy Photo picker retirement are established. The active D-owned completion slice is #941 Image Inspector parity.
- #941 — canonical Image preview/editing in shared Object Inspector: **active**, draft PR #1002.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Continue only for concrete remaining presentation/caller-zero work after the current #941 slice or when it can proceed independently without conflicting shared hotspots.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is compatibility projection only where legacy mapping still requires it.
- Canonical Person `Profile Image` Relation is the profile-photo authority; legacy `Person.profilePhotoId` is compatibility data, not a D-owned second identity path.
- Never infer physical-delete authority merely from a Vault-looking path, content hash, or arbitrary stored path.

## #245 integrated state
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media, Bookmark Relation integration, and Person profile-image integration.

Recent relevant integrated checkpoints:
- #866 completed the canonical content-first Images collection picker and closed #495.
- #869 / #876 routed canonical Image/Weblink media through generic List/Table hosts.
- #881 / #889 / #892 / #901 / #914 / #921 / #930 migrated Bookmark-facing image selection, mutation, reverse lookup, Stage1 filtering/drop, and create flow to canonical Image/Relation authority.
- #895 / PR #922 established strict fail-closed Relation mutation preflight and rollback-safe compatibility projection for Bookmark Image writes.
- #896 / PR #908 established first-run canonical Images masonry Gallery defaults without resetting user View customization.
- #945 / #947 established canonical Person identity and Person -> `Profile Image` Relation.
- #948 / PR #973 moved People profile imagery/mutations to canonical Image/Relation behavior.
- #981 retired the now caller-zero legacy Photo picker.
- Legacy `Photos`, `bookmark_photos`, `Person.profilePhotoId`, `photo_object_links` and selected compatibility reads remain until caller-zero proof, navigation retirement, preservation validation and any separate destructive-schema decision.

## Active slice — #941 / PR #1002
Goal: compose the existing canonical `ObjectImageDetailPanel` into the real shared `ObjectInspectorPage` without creating another preview/edit path.

Branch: `feature/primitives-image-inspector-941-v2`.

Current branch commits from this run:
- production composition already present: canonical Image-only panel, `CanonicalImageEditService.fromStores(...)`, active path resolver/ObjectStore reuse, metadata refresh after edits, privacy-safe edit/reload failure messages;
- `5754441a3ce44aed7c5bd7623dc478bee93cd99a` — replace `pumpAndSettle()` in existing Image Inspector editability coverage with bounded readiness pumping and unmount-before-DB-close cleanup;
- `56e4f0ff9fced2d077c94ee925e46f1287397960` — apply the same bounded readiness strategy to the focused native/legacy/custom Image Inspector integration regression.

Why the test change is required:
- CI #2932 test-shard 0 failed deterministically on first pass and identical rerun because `object_inspector_image_editing_test.dart` waited for the entire widget tree to settle after the Image panel introduced asynchronous preview/edit-availability state and progress animation;
- the regression needs to wait only for the specific Inspector state under assertion, not for every descendant animation to become globally idle;
- assertions are preserved: canonical Image title/Note editability, legacy-mirror read-only behavior, canonical panel presence, and custom Image-like ObjectType exclusion remain explicit.

## Tooling dependency status
#999 / PR #1003 is **resolved and merged**.

- PR #1003 Flutter CI #2936: full green.
- Squash merge: `8e466f3dcbb8fdb8bb22fdffbed59d4ab07f3b13`.
- Normal changed-Dart formatting is now hunk-aware for existing tracked files, so a patch-sized change to historically unformatted `object_inspector_page.dart` no longer requires unrelated broad formatter churn.
- New/untracked Dart files and explicit repository-wide format checks remain strict whole-file checks.

## Validation / CI
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub Actions is the executable validation source.
- PR #1002 CI #2932 before the test fix:
  - shared-hotspot overlap audit: pass;
  - maintainability guards: pass;
  - legacy dependency guard: pass;
  - presentation-error privacy guard: pass;
  - old whole-file format gate: fail due pre-existing Inspector formatter drift;
  - test-shard 3/4: pass;
  - test-shard 0/4: deterministic `pumpAndSettle()` timeout in existing `object_inspector_image_editing_test.dart` on first pass and rerun.
- Current meaningful head: `56e4f0ff9fced2d077c94ee925e46f1287397960`.
- CI #2940 was triggered for the bounded-pump test fix; because #1003 merged after that run was queued, the next meaningful checkpoint on this branch must be validated against current main `8e466f3dcbb8fdb8bb22fdffbed59d4ab07f3b13` before #1002 leaves draft.

## Current hotspot / concurrency state
Latest audited main: `8e466f3dcbb8fdb8bb22fdffbed59d4ab07f3b13`.

Live open PR audit at this checkpoint:
- #1002 — Lane D, `lib/views/object_inspector_page.dart` plus focused Image Inspector tests; this is the active Inspector hotspot lease.
- #997 — Lane C, patch-sized `app_shell.dart` command-palette work; no Inspector overlap.
- #990 — Lane G, `app_database.dart` Person legacy Photo mutation narrowing; no Inspector overlap.

No other open PR currently owns `object_inspector_page.dart`. Re-audit live state before further hotspot edits.

## Exact next actions
1. Read CI #2940 and distinguish old-base format failure from D-owned test/analyze failures.
2. Ensure a meaningful current-main validation run exists after #1003 integration; use the required handoff/PR metadata checkpoint rather than a no-op CI trigger.
3. Fix any D-owned Analyze/test failure without broad Inspector formatting or unrelated refactoring.
4. When format + Analyze + all four Flutter Test shards are green on current main, mark PR #1002 ready and merge it.
5. Close #941 only after merged-current-main verification, then update #245 to remove #941/#999 as active blockers.
6. Re-audit #245/#155 and live PR ownership for the next D-owned concrete slice; do not perform Lane C navigation retirement or Lane G caller-zero deletion from D.

## Cross-lane dependencies
- Lane B: preserve #895/#922 strict Relation mutation preflight for every Bookmark Image writer.
- Lane C: #949 owns making canonical `Images` the single normal user-facing collection/navigation surface; final legacy `写真` navigation retirement waits for #941 merge.
- Lane G: #999 is complete; #950 owns behavior-preserving caller-zero legacy Photo cleanup after product parity.
- Lane F: #951 owns final real-macOS/Vault preservation validation before the #245 umbrella can close.
- Lane E: owns Search persistence/reconciliation; Lane D emits primitive facts and does not write FTS directly.

## Known risks / boundaries
- Do not delete legacy Photo schema/data merely because replacement UI exists.
- Do not bypass canonical Relation APIs or shared-file edit/delete ownership checks.
- Do not expose raw filesystem paths or exceptions in user-facing Image errors.
- Keep the #941 patch focused; no broad refactor of `ObjectInspectorPage` in this product PR.
- Legacy Photo mirrors may preview through canonical Image resolution but must not gain an edit-safety bypass.

## Current run state
Work is **in progress**, not stopped. The immediate checkpoint is current-main CI validation for PR #1002 after the bounded-readiness test fix and the merged #1003 format-guard dependency.
