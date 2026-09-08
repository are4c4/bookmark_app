# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation. GitHub live state overrides historical notes below.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity and shared Object opening/detail contracts coherent across built-in and user-defined ObjectTypes. Lane A may expose generic, Search-agnostic Object mutation/completion metadata when downstream systems need trustworthy canonical Object identity, but Lane A does not own Search projection/FTS writes.

## Current active scope — 2026-09-08
- #56 — umbrella only; take work from it only when a concrete Object/ObjectType/Body/detail/opening correctness gap is demonstrated.
- #945 — **completed/closed** after PR #954 established canonical Person Object identity.

Focused Lane A issues completed/closed:
- #481 — universal Object Body across all real shared opening surfaces.
- #249 — Bookmark Gallery/List presentation parity routed temporarily to Lane A.
- #910 — protect Daily Note Date identity from generic Value edits.
- #909 — exact canonical Object impact from live mirror sync.
- #945 — stable canonical Person Object identity for legacy People promotion.

There is currently **no known independent Lane A production slice** after #945 completion. Idle is correct until #56 or real usage exposes another concrete Object-core/Body/detail/opening/identity regression or an Issue explicitly routes a new Object-core prerequisite here.

## Integrated Object/Core state
Major correctness checkpoints on `main` include:
- universal Body editing for system/custom ObjectTypes and Daily Notes (#503/#689/#874);
- persisted Property metadata/type/semantics remain authoritative and computed/intrinsic values fail closed on direct writes (#699/#724/#835);
- concurrent Object creation returns the exact inserted identity (#712);
- reusable ObjectType Body templates and focused default updates (#511/#517);
- Body structure/version/block identity/field-shape validation is fail-closed while unknown/future blocks remain forward-compatible (#521/#749/#755/#761/#796);
- Bookmark detail composes canonical Object Body without manufacturing missing mirrored Object identity (#780);
- corrupt Body reads expose the shared safe retry boundary instead of editable empty content (#811);
- ObjectType template application preflights invalid definitions before side effects and keeps primitive provisioning in the same transaction (#827/#833/#843);
- identity-managed Value Properties can be protected from generic mutation without making every system Property read-only (#910);
- live legacy-to-canonical mirror sync reports exact semantic canonical Object impact without importing Search or exposing legacy/user payload (#909);
- canonical Person Object identity/mapping now exists and participates in the same live sync impact path (#945/#954).

Search indexing of Body/title/aliases/properties remains Lane E-owned; Relation lifecycle remains Lane B-owned. Do not create duplicate pipelines here.

## Universal Body — #481 completed
The reusable canonical `ObjectBodyEditorSection` is integrated across shared Inspector/detail, side peek, center peek/full-page paths, Daily Notes/custom ObjectTypes and Bookmark detail through canonical Object identity. Broad behavior-preserving extraction from `ObjectInspectorPage` remains Lane G/#225 work rather than speculative Lane A work.

## Daily Note Date identity — #910 completed
PR #919 merged as `2ef65ae406067dde3c8ecb048e3119d89448c11c` after full Flutter CI.

The integrated contract is:
- canonical Daily Note `Date` is marked `config['identityManaged'] == true`;
- `DailyNoteService.ensureDefinition(...)` backfills and validates that contract idempotently;
- generic detail/Database Value writes reject overwriting initialized identity-managed values;
- trusted Daily Note lifecycle code may initialize identity during creation;
- a future move-to-another-date feature must be a separately designed atomic Object-owned operation.

## Exact live Object sync impact — #909 completed
PR #923 merged as `03acb81633031cb833975196b29f66947d9de747` after full Flutter CI.

The Object-owned contract remains:
- `ObjectSyncImpact` contains sorted/deduplicated canonical Object ids only;
- semantic snapshots compare canonical title + persisted Value state, excluding timestamps and legacy/user payload;
- initial workspace bootstrap is non-notifying;
- later successful same-workspace sync notifies only exact semantic changes;
- downstream callback failure is isolated from canonical persistence;
- Search owns how those canonical ids are refreshed/indexed.

## Canonical Person Object identity — #945 completed
PR #954 merged to `main` as `e025c8b868499c43951fd5a2abcde91bd8bf2de0` after Flutter CI #2855 passed maintainability/privacy/legacy guards, Drift generation, Analyze and the full Flutter test suite.

The integrated contract is:
- system `person` ObjectType uses the existing canonical Object/ObjectType persistence; no Person-specific Object store exists;
- hidden `Legacy Person ID` is a Number Property marked system + hidden + identity-managed;
- ordinary `Note` canonical Property mirrors legacy Person note content while legacy People rows remain intact;
- `person_object_links(workspace_id, person_id, object_id)` stores only the migration association with one-to-one constraints;
- display title is never the sole identity key;
- repeated sync/promotion reuses the same canonical Object id;
- a missing mapping is recoverable only when exactly one canonical Person Object claims the legacy Person id;
- ambiguous claims, damaged mappings, wrong/missing Object targets, legacy-id mismatches and incompatible system schema fail closed rather than manufacturing replacement identity;
- Person rename/note changes update the same canonical Object identity;
- Person candidates participate in the existing #909 semantic `ObjectSyncImpact` path.

Focused regressions cover initial create/reuse, rename/note identity preservation, hidden identity metadata, unambiguous missing-link recovery, ambiguous/damaged state, workspace scoping, schema preflight side-effect safety and live exact Person sync impact.

This completion unblocks #947, whose primary owner is **Lane B — Relations & Data Integrity**. Lane A has recorded the dependency release on #947. Do not implement the Person -> Profile Image Relation in Lane A.

## ObjectType/template integrity status
Current Lane A core requirements are integrated:
- deterministic invalid definitions fail before canonical primitive provisioning;
- primitive provisioning participates in the same transaction as user-owned ObjectType/Property/View/template output;
- later template versions do not silently rewrite customized user-owned definitions;
- unsupported persisted Property storage types fail closed;
- template-local Property identities follow persistence naming/normalization rules.

General template/domain instantiation UX, View labels/layout/grouping and schema-management presentation remain Lane C concerns.

## Hotspot ownership / concurrency
Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

- Re-check latest `main` and open PR ownership immediately before editing.
- #954 did not edit `app_database.dart` or broad People UI hotspots.
- The #945 Person identity lease is released after merge.
- No Lane A shared-hotspot lease is currently held.
- Prefer core Store/Service/domain/test fixes when a concrete Object invariant can be enforced below presentation.

## Cross-lane boundaries
- Weblink/Image/File/Tag primitive identity, metadata/enrichment, managed media and Photo -> Image product migration: Lane D (#155/#245).
- Relation mutation/read/index/backlink/audit/reconcile correctness, including Person -> Profile Image after #945: Lane B (#947).
- Database/View/template/schema UX and generic layout/default View contracts: Lane C.
- Search projection/refresh/indexing and FTS invalidation planning: Lane E.
- Vault/filesystem/release lifecycle: Lane F.
- behavior-preserving hotspot reduction and caller-zero legacy deletion: Lane G/#225.

## Exact next actions
1. On the next Lane A run, re-read live #56/#245 child routing, latest `main`, `docs/AI_PROGRESS.md`, this file, open Issues and open PR ownership.
2. Take only a concrete Object/ObjectType/Body/Daily Note/shared-opening/identity correctness regression or an explicitly routed Object-core prerequisite.
3. Do not take #947 Relation work, #948 People Image UI, #941 Image Inspector composition, #949 Database/View retirement, #950 refactor cleanup or #951 Storage validation merely because they depend on Person Objects.
4. Do not invent RichText/new schema types, Body abstractions, sync/event infrastructure or speculative Object features merely to keep Lane A active.
5. If no concrete Lane A item exists, stop under the `AGENTS.md` idle/no-actionable-work condition.

## Latest run checkpoint — 2026-09-08
- Re-audited current `main`, open Issues and open PR ownership after the previous idle checkpoint.
- Found new Lane A Issue #945 and active PR #954 establishing canonical Person Object identity.
- Verified #954 acceptance scope and boundaries against #945.
- Flutter CI #2855 on head `dec6c3a55c1a2f064c9d8d31637f7b3175facde8` passed maintainability/privacy/legacy guards, Drift generation, Analyze and full Flutter Test.
- PR #954 was squash-merged as `e025c8b868499c43951fd5a2abcde91bd8bf2de0`.
- Issue #945 was closed as completed.
- #947 was explicitly notified that its #945 prerequisite is now satisfied; #947 remains Lane B-owned.
- Live open A-routing audit after #945 completion shows no additional independent Lane A-only production slice.
- Production work in progress: **none in Lane A**.
- Blockers: none.
- Stop reason after handoff integration: **no remaining actionable independent Lane A-only acceptance item is known**.
