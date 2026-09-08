# AI Progress — Database, View & Schema UX Lane

> Lane C durable handoff. Always re-read `AGENTS.md`, the active GitHub Issue, `docs/AI_PROGRESS.md`, latest `main`, open PR ownership, and current CI before changing code. GitHub Issues/PRs/CI are the live source of truth; branch/commit/CI details below are dated checkpoints only.

## Lane goal
Make ObjectType / Database / View / schema configuration expressive and safe enough that new domains normally require configuration/templates rather than dedicated management pages.

## Active focused work
Lane C is **active on #949 — Photo→Image: make Images the single user-facing image collection**.

The convergence target is deliberately generic:
- canonical `画像` remains an ordinary persisted Database/View surface;
- no new Image-specific management page or second View-settings authority is introduced;
- user-owned Views and the first-use Images masonry/direct-Image Gallery contract remain intact;
- legacy Photo storage/rows remain compatibility data during navigation retirement;
- caller-zero deletion of the old Photo implementation belongs to Lane G after Lane C removes normal UI reachability.

## Durable prerequisites and checkpoints
The following prerequisites for #949 are already complete:
- #896 / PR #908 (`12994803…`) — canonical Images seed exactly one ordinary shared masonry/direct-Image Gallery only when zero Views exist; existing user Views win unchanged.
- #948 — People profile-photo UI no longer requires legacy Photo selection as its authority.
- #999 / PR #1003 (`8e466f3d…`) — changed-Dart format validation is hunk-aware for existing tracked files, allowing patch-sized shared-hotspot edits without unrelated formatter churn while remaining strict on edited/new code.

The remaining product prerequisite for final Photo navigation retirement is #941, owned by Lane D. PR #1002 composes the canonical Image panel into the shared Object Inspector. Lane C must verify the live PR/Issue/CI state before treating that dependency as complete.

## #949 implementation state — 2026-09-08 checkpoint
### Generic command-palette parity
PR #997, branch `feature/database-view-images-command-palette-949`, adds persisted generic Database destinations to the existing ⌘K command palette and routes them through the same `GenericDatabasePage` state as sidebar navigation.

Durable behavior:
- generic Database names/icons come from persisted definitions rather than Image-specific routing;
- selecting canonical `画像` sets the selected generic Database id and opens page 11 through the existing generic host;
- a real shell regression provisions canonical Images, searches `画像` in ⌘K, opens it, and verifies a canonical Image object is visible;
- the test intentionally searches before selecting because generic Databases follow fixed destinations in the lazy command list and may otherwise be outside the initial viewport.

Relevant checkpoints:
- `610eedf0…` — fixes the regression to use the real search-first command-palette UX;
- `49ef67b8…` — formats only the C-owned command-palette hunks after #1003 made the guard hunk-aware.

Do not infer current merge/CI status from this file; re-read PR #997 and its latest checks.

### Final legacy `写真` navigation retirement
A production caller audit established that normal `PhotoManagementPage` reachability is concentrated in `lib/views/app_shell.dart`. Closed/unmerged PR #988 is diagnostic evidence only and must not be resurrected.

After #941 is integrated, the intended final Lane C patch is limited to AppShell navigation reachability:
1. remove the `photo_management_page.dart` import;
2. remove expanded-sidebar `写真` destination (page 5);
3. remove collapsed-sidebar page-5 Photo icon;
4. remove fixed command-palette `写真` destination;
5. remove the page-5 `PhotoManagementPage` route.

Preserve the other numeric page ids and dynamic generic Database routing. Do **not** delete Photo rows, files, schema, compatibility bridges, or the old implementation file in this Lane C slice.

Add focused real-host coverage proving:
- legacy `写真` is not a normal AppShell navigation destination;
- canonical `画像` remains reachable through generic Database navigation/⌘K;
- existing Vault/Photo compatibility data is not mutated by the navigation change.

After merge, re-audit production callers. If `PhotoManagementPage` is caller-zero, hand that deletion opportunity to Lane G.

## Shared hotspot ownership
`lib/views/app_shell.dart` is the active Lane C hotspot for #997 and the later final navigation-retirement slice. Treat ownership as time-sensitive: inspect every open PR diff immediately before editing or integration. Patch-sized changes may proceed only when the live overlap audit confirms the same behavior/region is not concurrently owned.

Lane C does not own `object_inspector_page.dart`; #941/PR #1002 belongs to Lane D.

## Existing Database/View contract to preserve
System collection first-use behavior remains ordinary persisted View configuration:
- canonical Images: first zero-View open -> `ギャラリー`, `layoutType=gallery`, masonry, direct Image cover;
- canonical Weblinks: first zero-View open -> `リスト`, `layoutType=list`;
- any existing persisted View wins unchanged;
- ordinary custom ObjectTypes continue through the normal Database definition/default View path;
- system identity uses stable system keys, never display names.

Lane C owns generic Database/View/schema/navigation behavior, not Image/Weblink identity, media storage, editing semantics, Relation mutation, or Vault filesystem lifecycle.

## Earlier completed Lane C milestones
- #490 — user-owned ObjectType/Database/View templates and generic composability proof.
- #491 — Relation Property authoring + canonical target quick-create/import composition.
- #492 — configurable Relation-backed Gallery cover in the real generic Database host.
- #493 — safe/reversible Property schema evolution and real-host schema management.
- #481 — universal Object Body side-peek composition.
- #896 — canonical Images first-use Gallery provisioning.
- #920 — canonical Weblinks first-use List provisioning.

Do not resurrect completed work from stale umbrella checklists. Manual Database membership include/exclude remains deferred until real use demonstrates a concrete need.

## Validation contract
GitHub Flutter CI is the merge gate because local Flutter/Dart execution is unavailable in this automation environment.

For #949 slices require:
- shared-hotspot / maintainability / legacy-dependency / presentation-error guards;
- changed-Dart format validation;
- Drift generation + Flutter Analyze;
- all required Flutter Test shards;
- focused AppShell navigation regression.

Use CI diagnostic logs/artifacts for deterministic failures rather than broad speculative code changes.

## Cross-lane dependencies
- Lane D owns #941 Image Inspector parity and Image primitive behavior.
- Lane G owns caller-zero legacy implementation deletion and general maintainability work.
- Lane B owns Relation integrity; final navigation retirement must not alter Relation data.
- Lane F owns Vault/filesystem lifecycle; final navigation retirement must not delete/move managed bytes.

## Next actions
On resume, in priority order:
1. inspect live PR #997 checks; if green, current, and mergeable, integrate the generic command-palette parity slice;
2. inspect #941 / PR #1002 and help diagnose CI only as needed without taking Lane D ownership;
3. once #941 is integrated, refresh from latest `main`, re-audit AppShell hotspot overlap, and create the focused final `写真` navigation-retirement slice described above;
4. require full CI green, merge it, re-audit `PhotoManagementPage` callers, and close #949 when `画像` is the only normal user-facing image collection/navigation surface;
5. hand caller-zero Photo implementation cleanup to Lane G without deleting compatibility data.

## Stop / resume rule
Lane C should not stop merely because one PR or CI run is pending. Continue independent #949 work when safe. A valid stop exists only when the remaining next step is genuinely blocked by the cross-lane #941 integration, an unavoidable hotspot conflict, external infrastructure, or another `AGENTS.md` stopping condition.
