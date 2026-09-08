# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation. GitHub live state overrides historical notes below.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity and shared Object opening/detail contracts coherent across built-in and user-defined ObjectTypes. Lane A may expose generic, Search-agnostic Object mutation/completion metadata when downstream systems need trustworthy canonical Object identity, but Lane A does not own Search projection/FTS writes.

## Current active scope — 2026-09-08
- #56 is the umbrella. Take work from it only when a concrete Object/ObjectType/Body/detail/opening correctness gap is demonstrated.
- Focused Lane A issues #481, #249, #909 and #910 are completed/closed.
- There is currently **no known independent Lane A production slice** after #909/#910 completion. Idle is correct until #56 or real usage exposes another concrete Object-core/detail regression.

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
- live legacy-to-canonical mirror sync can report exact semantic canonical Object impact without importing Search or exposing legacy/user payload (#909).

Search indexing of Body/title/aliases/properties remains Lane E-owned; Relation lifecycle remains Lane B-owned. Do not create duplicate pipelines here.

## Completed focused milestones
### Universal Body — #481
#874 (`38c20b67…`) completed the final cross-host requirement by composing reusable canonical Body editing into Generic Database side peek. The same persisted Body contract now spans shared Object Inspector/detail, side peek, center peek/full page, Daily Notes/custom ObjectTypes, and Bookmark detail through the canonical Bookmark -> Object identity boundary.

Broad behavior-preserving extraction from `ObjectInspectorPage` belongs with Lane G/#225 coordination rather than speculative Lane A work.

### Bookmark presentation parity — #249
#885 (`38494512…`) completed the routed Bookmark Gallery/List parity slice using shared Database/View Gallery infrastructure. Future Bookmark/Weblink/Image presentation convergence belongs to Primitive/Database/View/Refactor work, not Lane A merely because Bookmark Objects are involved.

### Daily Note Date identity — #910
PR #919 merged as `2ef65ae406067dde3c8ecb048e3119d89448c11c` after full Flutter CI green.

Integrated contract:
- canonical Daily Note `Date` is marked `config['identityManaged'] == true`;
- `DailyNoteService.ensureDefinition(...)` idempotently backfills the marker while validating the schema;
- generic detail and Database Value writes reject edits to initialized identity-managed Values;
- the owning lifecycle may initialize the value during trusted creation;
- ordinary custom Date Properties remain editable.

A future “move Daily Note to another date” feature must be a separately designed atomic Object-owned operation that updates registry identity and Date together and handles collisions explicitly.

### Exact live Object sync impact — #909
PR #923 merged as `03acb81633031cb833975196b29f66947d9de747` after full Flutter CI green.

Integrated contract:
- immutable `ObjectSyncImpact` contains sorted/deduplicated canonical Object ids only;
- semantic snapshots compare canonical Object title + persisted Value state and deliberately exclude timestamps and legacy/user payload;
- bridge/full sync reports candidates only for successful canonical semantic changes;
- initial workspace activation establishes the baseline and remains non-notifying;
- later same-workspace sync notifies only when exact impact is non-empty;
- downstream callback failure remains isolated after canonical persistence succeeds.

Search owns what to do with these ids. Do not move FTS invalidation/planning into Object sync services.

## Hotspot ownership / concurrency
Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

Always re-check current open PRs immediately before editing.

Live audit on 2026-09-08 at `main` `7cf55531d7637418af77a5acf56e63ee82e9a276`:
- PR #943 is Lane D and changes Bookmark detail/attachment canonical Weblink URL presentation.
- PR #944 is Lane G and retires caller-zero BookmarkRepository/WorkspaceStore facades.
- Neither PR establishes a Lane A hotspot lease.
- Open Issue #941 is explicitly Lane D and plans a focused `ObjectInspectorPage` canonical Image preview/editing composition. Lane A must not take that implementation merely because the shared Inspector is in Object presentation.
- No Lane A shared-hotspot lease is currently held.

Prefer core Store/Service/domain/test fixes below presentation when a real Object invariant can be enforced there. Coordinate broad Body/detail extraction with Lane G/#225.

## Cross-lane boundaries
- Weblink/Image/File/Tag identity, metadata/enrichment, managed media, canonical image import/editing and Photo -> Image migration: Lane D (#155/#245).
- Relation mutation/read/index/backlink/audit/reconcile correctness and corruption handling: Lane B.
- Database/View/template/schema UX and generic layout/default View contracts: Lane C.
- Search projection/refresh/indexing and FTS invalidation planning: Lane E.
- Vault/filesystem/release lifecycle: Lane F.
- behavior-preserving hotspot reduction and caller-zero legacy deletion: Lane G/#225.

#909 sharing exact canonical Object ids with Search does not transfer Search ownership to Lane A.

## Exact next actions
1. On the next Lane A run, re-read live #56, latest `main`, `docs/AI_PROGRESS.md`, this file, open Issues and open PR ownership.
2. Take only a concrete Object/ObjectType/Body/Daily Note identity/detail/opening correctness regression or an explicitly routed Object-core acceptance item.
3. Do not invent RichText/new schema types, Body abstractions, template validation, sync/event infrastructure or Bookmark presentation work merely to keep Lane A active.
4. If a new issue belongs to Relation, Primitive, Search, Database/View, Storage or broad refactor semantics, leave implementation with that lane and expose only the minimum Object-core contract if explicitly required.
5. If no concrete Lane A item exists, stop under the `AGENTS.md` idle/no-actionable-work condition.

## Latest run checkpoint — 2026-09-08 16:xx JST
- Re-read live `AGENTS.md`, #56, `docs/AI_PROGRESS.md`, this Lane A handoff, latest `main`, open Issues and open PR ownership.
- Latest `main`: `7cf55531d7637418af77a5acf56e63ee82e9a276` (`Refresh Lane G handoff after caller-zero retirements (#942)`).
- Live open product Issues are #56, #155, #225, #242, #245 and #941. #941 is explicitly Lane D; none is a newly demonstrated independent Lane A-only production slice.
- Live open PRs are #943 (Lane D) and #944 (Lane G). Their current scopes do not transfer ownership of Object-core/Body work to Lane A.
- Production work in progress: **none in Lane A**.
- Blockers: none.
- Stop reason: **no remaining actionable independent Lane A-only acceptance item is known**. Resume only for a concrete #56/Object-core/Daily Note/detail/opening regression or explicit new Lane A routing.
