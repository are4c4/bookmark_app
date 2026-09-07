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
- #780 merged as `af8a816a04275cd25020916eebdc8c5338a659a8`: Bookmark detail now composes the canonical universal Object Body through a read-only Bookmark -> Object identity boundary; unmirrored legacy Bookmarks stay fail-soft and corrupt Body stays fail-closed.
- #796 merged as `e51506a8be1e796dde6d3f5cb4e7572a8d147410`: known checklist blocks reject a present non-boolean `checked` attribute before presentation; the same semantic validator protects persisted Body and ObjectType Body templates while unknown/future blocks remain opaque.
- #811 merged as `26d624fe4cd7d586f636ed255e3e5b341922aa40`: `ObjectDetailContentLoader` distinguishes unsafe persisted Body reads, and `ObjectInspectorPage` now fails closed with the shared `body-load-error` / `body-load-retry` contract instead of exposing an editable empty Body or async load error. Focused loader/widget regressions verify corrupt content remains unchanged and retry recovers after canonical repair.
- Universal Body text already participates in canonical Object search through Lane E; Lane A must not create a parallel note-search path.

## Universal Body status
The Lane A correctness path for #481 is integrated for canonical persisted content:
- system/custom ObjectInspector Body editing is universal;
- Weblink/Image identity-sensitive Property guards remain separate from Body mutability;
- custom Objects and Daily Notes retain the same Body contract;
- Bookmark detail uses the same canonical Body persistence/edit/action/reference services without a Bookmark-specific note table or writer;
- Bookmark presentation never manufactures a missing mirrored Object identity;
- unknown/rich blocks remain preserved, and malformed document/block structure or known checklist state fails closed before editable presentation;
- malformed persisted Body now has safe retry presentation in both the reusable `ObjectBodyEditorSection` and the shared `ObjectInspectorPage` host.

`ObjectInspectorPage` still contains Body editing orchestration that overlaps with the reusable `ObjectBodyEditorSection`. Consolidating that duplication would be a behavior-preserving shared-hotspot refactor rather than a prerequisite for the persisted Body contract, so coordinate with Lane G/#225 before a broad extraction.

## Known presentation gap
There is no remaining known Lane A-only universal-Body presentation correctness gap after #811. The explicit #481 product gap is cross-lane: generic Database side peek is still an alternate Lane C-owned composition surface and must reuse the canonical Body/detail seam before #481 can close.

Do not broaden Lane A into `generic_database_page.dart` to close that gap. Do not introduce another Body persistence/editor path. If a new Lane A issue is found, prefer a small core invariant/regression in Object/ObjectType/Body/detail contracts over speculative presentation work.

## Hotspot ownership / concurrency
- `generic_database_page.dart`, `object_inspector_page.dart` and `app_shell.dart` remain shared hotspots. Re-check live PR ownership before editing them.
- Prefer domain/store/service/test slices when a core invariant can be enforced below presentation.
- Parallel Object executions have been active; always re-fetch branch head immediately before writing to an existing Lane A branch.

## Cross-lane dependencies
- #481 cannot fully close until Lane C composes canonical Body into generic Database side peek / verifies its side-peek contract. Lane A should provide/reuse Body/detail contracts rather than broad-editing Database/View layout.
- Weblink/Image/File/Tag product identity, managed media and primitive actions belong to Lane D.
- Relation mutation/integrity belongs to Lane B.
- Search/index pipelines belong to Lane E; Body/alias/property data contracts stay Lane A-owned, but indexing pipelines should not be duplicated here.
- large behavior-preserving extraction from `ObjectInspectorPage` belongs with Lane G/#225 ownership coordination.

## Next actions
1. Re-audit #481 after Lane C side-peek work lands; do not close it while that acceptance item is unresolved.
2. Continue only with a concrete new #56/#484 Object core invariant or regression found from real usage; do not invent speculative schema types.
3. For #490/#493 follow-ups, keep only ObjectType/core/default ownership semantics in Lane A; Database/View impact UX stays Lane C and Relation schema lifecycle stays Lane B.
4. If Body editor duplication becomes an active maintainability task, coordinate a small behavior-preserving `ObjectInspectorPage` extraction with Lane G rather than racing the hotspot from Lane A.
5. Keep Weblink/Image/File product semantics in Lane D, Relation lifecycle in Lane B, Search in Lane E, and Database/View layout in Lane C.

## Current checkpoint
Persisted Object Body and ObjectType Body-template corruption boundaries are fail-closed through structure, field shape, version range, block identity and known checklist semantic state. Bookmark detail and `ObjectInspectorPage` both expose safe retry UI for corrupted Body without mutating or flattening stored content. There is no known remaining Lane A-only #481 correctness gap; the remaining explicit close blocker is generic Database side-peek Body composition/verification owned by Lane C.