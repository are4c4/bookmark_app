# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation. GitHub live state overrides historical notes below.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity and shared Object opening/detail contracts coherent across built-in and user-defined ObjectTypes. Lane A may expose generic, Search-agnostic Object mutation/completion metadata when downstream systems need trustworthy canonical Object identity, but Lane A does not own Search projection/FTS writes.

## Current active scope — 2026-09-08
- #56 — umbrella only; take work from it only when a concrete Object/ObjectType/Body/detail/opening correctness gap is demonstrated.

Focused Lane A issues completed/closed:
- #481 — universal Object Body across all real shared opening surfaces.
- #249 — Bookmark Gallery/List presentation parity routed temporarily to Lane A.
- #910 — protect Daily Note Date identity from generic Value edits.
- #909 — exact canonical Object impact from live mirror sync.

There is currently **no known independent Lane A production slice** after #909/#910 completion. Idle is correct until #56 or real usage exposes another concrete Object-core/detail regression.

## Integrated Object/Core state
Major correctness checkpoints on `main` include:
- universal Body editing for system/custom ObjectTypes and Daily Notes (#503/#689);
- persisted Property metadata/type/semantics remain authoritative and computed/intrinsic values fail closed on direct writes (#699/#724/#835);
- concurrent Object creation returns the exact inserted identity (#712);
- reusable ObjectType Body templates and focused default updates (#511/#517);
- Body structure/version/block identity/field-shape validation is fail-closed while unknown/future blocks remain forward-compatible (#521/#749/#755/#761/#796);
- Bookmark detail composes canonical Object Body without manufacturing missing mirrored Object identity (#780);
- corrupt Body reads expose the shared safe retry boundary instead of editable empty content (#811);
- ObjectType template application preflights invalid definitions before side effects and keeps primitive provisioning in the same transaction (#827/#833);
- template Property names/references use canonical persistence naming rules and reject blank/padded/normalized-duplicate identities before provisioning (#843);
- identity-managed Value Properties can be protected from generic mutation without making every system Property read-only (#910);
- live legacy-to-canonical mirror sync can report exact semantic canonical Object impact without importing Search or exposing legacy/user payload (#909).

Search indexing of Body/title/aliases/properties remains Lane E-owned; Relation lifecycle remains Lane B-owned. Do not create duplicate pipelines here.

## Universal Body — #481 completed
#874 (`38c20b67…`) completed the final cross-host requirement by composing the reusable canonical `ObjectBodyEditorSection` into Generic Database side peek. The same persisted Body contract now spans:
- shared Object Inspector/detail;
- side peek;
- center peek/full-page shared opening paths;
- Daily Notes and custom ObjectTypes;
- Bookmark detail through the canonical Bookmark -> Object identity boundary.

#481 is completed/closed. The old statement that Generic Database side peek blocks #481 is obsolete.

`ObjectInspectorPage` still contains Body orchestration that overlaps reusable Body components. Broad behavior-preserving extraction belongs with Lane G/#225 coordination rather than speculative Lane A work.

## Bookmark presentation parity — #249 completed
#885 (`38494512fc2ba119fecb3f94e6973577aa665f67`) completed the last real Stage1 Gallery parity slice by reusing shared `ObjectGalleryModeMenu`, `DatabaseViewGalleryAdapter` and `ObjectGalleryView`, persisting `settings['galleryMode']` per Bookmark View without a Bookmark-only renderer/setting.

Flutter CI #2712 passed all maintainability/feature guards, Drift generation, Analyze and the full Flutter test suite after the widget teardown regression was corrected. #249 is completed/closed.

Future Bookmark/Weblink/Image presentation convergence belongs to the currently routed Primitive/Database/View/Refactor work, not Lane A merely because Bookmark Objects are involved.

## Daily Note Date identity — #910 completed
PR #919 merged as `2ef65ae406067dde3c8ecb048e3119d89448c11c` after Flutter CI #2778 passed the full repository suite.

The integrated contract is:
- the canonical Daily Note `Date` Property is marked with reusable Object-core metadata `config['identityManaged'] == true`;
- `DailyNoteService.ensureDefinition(...)` idempotently backfills that marker while preserving the existing Property id/config and validating the Date schema;
- `ObjectDetailEditService` rejects generic edits to identity-managed Values before persistence;
- `GenericDatabaseStore.setValue(...)` consumes the same metadata contract so low-level generic Database Value writes cannot overwrite an already-initialized identity-managed value;
- the owning lifecycle may still initialize the value during trusted creation;
- ordinary custom Date Properties remain editable;
- registry claim + persisted Daily Note Date therefore cannot be separated by the generic edit paths currently used by shared detail/Table surfaces.

A future “move Daily Note to another date” feature must be a separately designed atomic Object-owned operation that updates registry identity and Date together and handles collisions explicitly. Do not re-enable generic Date mutation as a shortcut.

## Exact live Object sync impact — #909 completed
PR #923 merged as `03acb81633031cb833975196b29f66947d9de747` after Flutter CI #2795 passed maintainability/privacy/legacy guardrails, Drift generation, `flutter analyze`, and the full Flutter test suite.

The integrated Object-owned contract is:
- immutable `ObjectSyncImpact` contains sorted/deduplicated canonical Object ids only;
- semantic snapshots compare canonical Object title + persisted Value state and deliberately exclude timestamps and legacy/user payload from the result contract;
- `CoreObjectBridge.syncAllWithImpact(...)` and `BookmarkWeblinkObjectBridge.syncWorkspaceWithImpact(...)` report candidates only for successful canonical semantic changes;
- `ObjectSyncService` compares the full pass before/after state so transient compatibility writes later retired by the Bookmark -> Weblink bridge do not become false-positive downstream invalidation;
- initial workspace activation establishes the baseline and remains non-notifying;
- later watcher-driven or explicit same-workspace sync notifies only when exact impact is non-empty;
- downstream callback failure remains isolated after canonical persistence succeeds and cannot roll back/retry the mirror;
- background preview Image completion from #902 remains a separate completion seam.

Regression coverage locks:
- create -> reported canonical Object id;
- unchanged repeated bridge/full sync -> empty/no callback;
- Bookmark title change -> Bookmark only;
- URL retarget to a new Weblink -> changed Bookmark + new target, not the old target merely because it was revisited;
- retarget to an already-existing/reused unchanged Weblink -> changed Bookmark only;
- deleted mirrored Bookmark -> exact deleted canonical Bookmark id, allowing Search to remove the stale row;
- Search callback failure -> canonical Bookmark -> Weblink persistence survives.

Search owns what to do with these ids. Do not move FTS invalidation/planning into `ObjectSyncService` or the bridges.

## ObjectType/template integrity status
Current Lane A core integrity requirements for the template path are integrated:
- deterministic invalid template definitions fail before canonical primitive provisioning;
- primitive provisioning participates in the same transaction as user-owned ObjectType/Property/View/template output;
- template-created definitions remain user-owned and later template versions do not silently rewrite customized instances;
- unsupported persisted Property storage types fail closed rather than becoming Text;
- template-local Property identities match persistence normalization.

General template/domain instantiation UX, View labels/layout/grouping and schema-management presentation remain Lane C concerns under current `AGENTS.md`.

## Hotspot ownership / concurrency
Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

- Re-check latest `main` and open PR ownership immediately before editing.
- The #909 `ObjectSyncService` lease is released after #923 merge.
- No Lane A shared-hotspot lease is currently held.
- Prefer core Store/Service/domain/test fixes below presentation when a real Object invariant can be enforced there.
- Coordinate broad Body/detail extraction with Lane G/#225.

## Cross-lane boundaries
- Weblink/Image/File/Tag identity, metadata/enrichment, managed media, canonical image import/editing and Photo -> Image migration: Lane D (#155/#245).
- Relation mutation/read/index/backlink/audit/reconcile correctness and corruption handling: Lane B.
- Database/View/template/schema UX and generic layout/default View contracts: Lane C.
- Search projection/refresh/indexing and FTS invalidation planning: Lane E.
- Vault/filesystem/release lifecycle: Lane F (#242 validation remains).
- behavior-preserving hotspot reduction and caller-zero legacy deletion: Lane G/#225.

#909 sharing exact canonical Object ids with Search does not transfer Search ownership to Lane A.

## Exact next actions
1. On the next Lane A run, re-read live #56, latest `main`, `docs/AI_PROGRESS.md`, this file, open Issues and open PR ownership.
2. Take only a concrete Object/ObjectType/Body/Daily Note identity/detail/opening correctness regression or an explicitly routed Object-core acceptance item.
3. Do not invent RichText/new schema types, Body abstractions, template validation, sync/event infrastructure or Bookmark presentation work merely to keep Lane A active.
4. If a new issue belongs to Relation, Primitive, Search, Database/View, Storage or broad refactor semantics, leave implementation with that lane and expose only the minimum Object-core contract if explicitly required.
5. If no concrete Lane A item exists, stop under the `AGENTS.md` idle/no-actionable-work condition.

## Latest run checkpoint — 2026-09-08
- Re-read `AGENTS.md`, live #909/#910 state, latest `main`, open PR ownership and both lane/repository handoffs.
- #910 / PR #919 completed and merged as `2ef65ae406067dde3c8ecb048e3119d89448c11c`; Issue #910 is completed/closed.
- #909 / PR #923 completed and merged as `03acb81633031cb833975196b29f66947d9de747`; Issue #909 is completed/closed.
- Flutter CI #2795 is full green on the final #923 head `058792e7553f83079a9bbe662d389a638120748e`.
- Concurrent main changes after #923's original base were audited before merge: Storage handoff, Weblinks default View and Relation integrity work did not overlap the four #923 files.
- Live open-Issue audit after #923 shows only #56, #155, #225, #242 and #245; none is a newly demonstrated independent Lane A-only production slice.
- Open PR audit at this checkpoint is empty.
- Current handoff branch: `docs/object-handoff-after-909-910`; docs-only, no runtime behavior change.
- Production work in progress: **none in Lane A**.
- Blockers: none.
- Stop reason after this handoff is integrated: **no remaining actionable independent Lane A-only acceptance item is known**. Resume only for a concrete #56/Object-core/Daily Note/detail regression or explicit new Lane A routing.
