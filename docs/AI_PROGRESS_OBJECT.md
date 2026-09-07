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
- #749 merged: malformed present Body `version` / `blocks` fields fail closed instead of silently becoming current-version/empty Body.
- #761 merged: Body versions are one-based; zero/negative versions fail closed on read and serialization while positive future versions remain forward-compatible.
- #755 merged: persisted Body block `id` / `type` / `text` / `attributes` field shapes fail closed instead of being stringified or flattened; valid unknown block attributes remain forward-compatible.
- Universal Body text already participates in canonical Object search through Lane E; Lane A must not create a parallel note-search path.

## Active slice
PR #780 — `feature/object-bookmark-universal-body-main2-481`

Goal: expose the canonical universal Object Body inside the actual Bookmark detail composition without moving primitive identity or Relation lifecycle into Lane A.

Current implementation:
- `ObjectBodyEditorSection` is backed by the canonical Body store/edit/action/reference services.
- `BookmarkObjectDetailContext` resolves Bookmark -> mirrored Object identity through a read-only boundary; presentation never manufactures missing identity.
- `BookmarkObjectBodySection` isolates Bookmark ID resolution and canonical Body composition from the legacy backlink stream.
- `BookmarkRelationSection` keeps its existing Relation implementation intact and adds only a five-line Body-host composition diff after that surface.
- corrupt persisted Body remains fail-closed with retry instead of becoming an editable empty document.
- Object references open through canonical Object detail.

Validation / CI:
- stale #732 reached a fully green Flutter CI after its focused regression was separated from `CoreObjectBridge.syncAll()` and the legacy `BacklinkRepository` stream.
- #780 recreates that green implementation from newer `main` after #755, with a smaller `BookmarkRelationSection` diff; process #780's own normal CI before merge.
- latest #780 implementation head at creation is `3047709d3652a9be07532562ec3ff83e2221fd35`; always re-fetch the PR head before a write or merge because `main` and parallel lanes advance frequently.

## Hotspot ownership / concurrency
- `generic_database_page.dart`, `object_inspector_page.dart` and `app_shell.dart` remain shared hotspots. Re-check live PR ownership before editing them.
- Prefer domain/store/service/test slices when a core invariant can be enforced below presentation.
- Parallel Object executions have been active; always re-fetch branch head immediately before writing to an existing Lane A branch.

## Cross-lane dependencies
- #481 cannot fully close until Lane C composes canonical Body into generic Database side peek. Lane A should provide/reuse Body/detail contracts rather than broad-editing Database/View layout.
- Weblink/Image/File/Tag product identity, managed media and primitive actions belong to Lane D.
- Relation mutation/integrity belongs to Lane B.
- Search/index pipelines belong to Lane E; Body/alias/property data contracts stay Lane A-owned, but indexing pipelines should not be duplicated here.

## Next actions
1. Process current PR #780 CI and fix only failures caused by the latest-main recreation.
2. Merge #780 when green/mergeable and the branch head is unchanged.
3. Re-audit #481 acceptance after #780; generic Database side-peek Body remains a Lane C dependency unless ownership changes explicitly.
4. Continue only with concrete #56/#484 Object core invariants not already protected by existing tests; do not invent speculative schema types or redesign Relation/primitive subsystems.
5. Keep this handoff synchronized after material Lane A merges so stale branch/PR instructions do not cause duplicate work.

## Current checkpoint
No known unresolved A-core corruption issue remains in Body template/default parsing, block identity, document/block field shape, version range, managed timestamps, aliases, Daily Note identity, or built-in-vs-user-defined schema protection. The active Lane A implementation risk is #780's latest-main Bookmark-detail integration CI/mergeability; the remaining generic Database side-peek Body composition is cross-lane Lane C work.
