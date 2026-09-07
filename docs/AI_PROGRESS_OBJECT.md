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
- #699 merged: `ObjectStore.setPropertyValue` treats persisted Property ObjectType/type/semantics as authoritative and rejects forged metadata/computed direct writes.
- #712 merged: concurrent generic Object creation returns the exact inserted row id.
- #724 merged: intrinsic `createdTime` / `updatedTime` remain read-only through the shared Object detail mutation contract.
- #511 merged: `ObjectTypeDefaults` can persist a reusable Body template and new Objects receive the current template without mutating existing Body.
- #517 merged: focused Body-template updates preserve other ObjectType presentation defaults.
- #521 merged: Object Body rejects blank/lossy block identities and duplicate block ids before persistence.
- #740 merged: ObjectType defaults reject duplicate Property ids on both write and read boundaries.
- #749 merged: malformed present Body `version` / `blocks` fields fail closed instead of being silently interpreted as current-version/empty Body; `{}` and future integer versions remain compatible.
- Universal Body text already participates in canonical Object search through Lane E; Lane A must not create a parallel note-search path.

## Active slice
PR #732 — `feature/object-bookmark-universal-body-main-481`

Goal: expose the canonical universal Object Body inside the actual Bookmark detail composition without moving primitive identity or Relation lifecycle into Lane A.

Current implementation:
- extracts reusable `ObjectBodyEditorSection` backed by the canonical Body store/edit/action/reference services;
- resolves Bookmark -> mirrored Object identity through the read-only `BookmarkObjectDetailContext` boundary;
- hosts the same canonical Body in Bookmark detail while keeping unmirrored legacy Bookmarks fail-soft;
- keeps corrupt persisted Body fail-closed with retry instead of presenting an editable empty document;
- routes Object-reference opening through canonical Object detail.

Validation / CI:
- production/analyze/maintainability checks are green across repeated #732 runs;
- earlier regression versions caused the full `flutter test` step to remain alive until the repository 18-minute job timeout, without an assertion failure;
- the current regression no longer invokes full `CoreObjectBridge.syncAll()` and instead seeds only the canonical Bookmark Object plus `bookmark_object_links` identity required by the detail read contract;
- process the current #732 CI before merge; do not reintroduce heavyweight bridge synchronization into the widget regression.

## Hotspot ownership / concurrency
- `generic_database_page.dart`, `object_inspector_page.dart` and `app_shell.dart` remain shared hotspots. Re-check live PR ownership before editing them.
- Prefer domain/store/service/test slices when a core invariant can be enforced below presentation.
- Parallel Object executions have been active; always re-fetch branch head immediately before writing to an existing Lane A branch.

## Cross-lane dependencies
- #481 cannot fully close until Lane C composes canonical Body into generic Database side peek. Lane A should provide/reuse Body/detail contracts rather than broad-editing Database/View layout.
- Weblink/Image/File/Tag product identity, managed media and primitive actions belong to Lane D.
- Relation mutation/integrity belongs to Lane B.
- Search/index contribution semantics belong to Lane E; Body/alias/property data contracts stay Lane A-owned, but indexing pipelines should not be duplicated here.

## Next actions
1. Process current PR #732 CI and fix only the focused Bookmark Body regression if it still fails or times out.
2. Merge #732 when green and the branch head is unchanged.
3. Re-audit #481 acceptance after #732; generic Database side-peek Body remains a Lane C dependency unless ownership changes explicitly.
4. Continue only with concrete #56/#484 Object core invariants that are not already protected by existing tests; do not invent speculative schema types or redesign Relation/primitive subsystems.
5. Keep this handoff synchronized after material Lane A merges so stale branch/PR instructions do not cause duplicate work.

## Current checkpoint
No known unresolved A-core corruption issue remains in Body template/default parsing, block identity, managed timestamps, aliases, Daily Note identity, or built-in-vs-user-defined schema protection. The active Lane A implementation risk is #732's Bookmark-detail integration regression/CI behavior; the remaining generic Database side-peek Body composition is cross-lane Lane C work.
