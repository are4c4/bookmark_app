# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity and shared detail/opening contracts coherent across built-in and user-defined ObjectTypes.

## Primary active issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening portions of the generic architecture umbrella.
- #484 — user-defined ObjectType core behavior and built-in-vs-user-defined boundary only.

## Current integrated state — 2026-09-07
- #503 merged: shared `ObjectInspectorPage` Body editing is universal for system and custom ObjectTypes.
- #689 merged: custom ObjectType and Daily Note universal Body regressions are covered.
- #698 remains an open Lane A PR exposing canonical Object Body in the Bookmark detail composition; generic Database side peek is still Lane C-owned.
- #699 merged: `ObjectStore.setPropertyValue` treats persisted Property ObjectType/type/semantics as authoritative and rejects forged metadata/computed direct writes.
- #712 merged as `cc6e34ca03fa23e12548c3d2c2a4a09f995999a7`: generic Object creation returns the exact inserted row id under concurrency.
- Universal Body text already participates in canonical Object search through completed Lane E work; Lane A must not create a parallel note search path.

## Active slice
Branch: `feature/object-detail-managed-values-main2`
Latest implementation commit: `df47276cc9b48e4c4c5813f1770ed0c64af6a6dc`

Goal: keep intrinsic Object timestamps read-only through the shared Object detail mutation contract.

Changes:
- `ObjectDetailEditService` rejects `createdTime` and `updatedTime` from generic stored-Value editing even though they remain Value semantics for presentation/filtering purposes.
- focused regression verifies both managed timestamp Property types fail closed and no `generic_values` entries are persisted.
- the same patch previously passed Flutter CI on #720, but that PR diverged after parallel merges; this branch recreates the exact production/test slice from latest main rather than force-merging stale history.
- no shared hotspot, Relation lifecycle, primitive implementation, Database/View layout, Search, Storage or Refactor cleanup is touched.

Validation:
- #720 head `36bf7cfe97d465a647ceb3e176a65b4b70b2052e` passed Flutter CI run #2270;
- replacement branch requires its own normal Flutter CI before merge.

## Hotspot ownership / concurrency
Open PR audit found no need to touch `object_inspector_page.dart`, `generic_database_page.dart`, `app_shell.dart` or `app_database.dart` for this slice. Continue preferring service/domain/test work while other lanes own shared presentation hotspots.

## Cross-lane dependencies
- #481 cannot fully close until Lane C composes canonical Body into generic Database side peek; Lane A should provide/reuse Body/detail contracts rather than editing Database/View layout itself.
- Weblink/Image/File-specific identity and managed media behavior belong to Lane D.
- Relation mutation/integrity belongs to Lane B.

## Next actions
1. Open replacement PR from `feature/object-detail-managed-values-main2`; close stale #720 as superseded.
2. Process CI for the replacement and fix only failures caused by this slice.
3. Merge when green/mergeable.
4. Re-audit #698 and any current Body/detail PR ownership; avoid duplicating its Bookmark composition work.
5. Continue with another independent #56/#484 Object core or typed Property semantic invariant from current main if available.
6. Keep #481 open until Lane C side-peek Body composition is integrated; do not broaden Lane A into `generic_database_page.dart`.

## Stop reason for this checkpoint
Latest main advanced while #720 was open, making the old branch diverged/non-mergeable despite green CI. The managed-timestamp slice has been recreated on current main without shared-hotspot edits; next execution should process replacement CI and continue with another safe core slice if available.
