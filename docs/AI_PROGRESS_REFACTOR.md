# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, current open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, measurable dependency reduction, `AppDatabase` narrowing, failure/privacy policy guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

Latest integrated `main` at this checkpoint: **`1f03e9254e49791d55f699b092b28a6d69681ddb`** (`#968`).

Current Lane G handoff branch: **`docs/refactor-handoff-after-968`**, docs-only from the checkpoint above.

Open PR ownership at this checkpoint is docs-only outside Lane G runtime ownership:
- #959 — Lane A handoff, `docs/AI_PROGRESS_OBJECT.md` only;
- #956 — Lane D handoff, `docs/AI_PROGRESS_PRIMITIVES.md` only.

This list is time-sensitive. Re-run the open-PR audit before every non-trivial edit; do not treat this handoff as a lock on future ownership.

Lane G has completed another caller-zero retirement sequence through #968. Fresh post-#968 audits found the obvious Bookmark People/Collection/Tag/engagement/read forwarders still have real production hosts, and the remaining Tag/Person-group/Photo/Attachment compatibility APIs inspected in this run are also live. Do not delete them merely because adjacent conveniences disappeared.

## Latest integrated Lane G checkpoints

Recent integration sequence:
- **#968 / `1f03e925…` — caller-zero PDF annotation list helper retired.** Removed `PdfAnnotationStore.listForAttachment(...)` after a current-main caller audit found only its definition. The live PDF viewer continues to use `watchForAttachment(...)`, `add(...)`, and `remove(...)`; its no-op `initialize()/dispose()` lifecycle calls remain because they are live and removing them would require a low-value broad viewer edit. Production diff: exactly 11 LOC deleted from one file. Flutter CI #2875 full green, including Analyze + full Test.
- **#964 / `a547eb89…` — durable Lane G handoff and legacy inventory reconciled.** Corrected the runtime Saved View retirement state, preserved legacy Saved View tables as compatibility/migration data, recorded the completed 0/0 Database-presentation shim state, and refreshed caller-zero exclusions. Flutter CI #2870 full green.
- **#963 / `22c94632…` — caller-zero Tag-group conveniences retired.** Removed `TagGroupStore.tagGroupIds()` and `setTagGroup(...)`; two test fixtures now use canonical `moveTag(...)`. Live `watchTagGroupIds()`, group management, move/restore, usage stats, merge/delete behavior, expansion state, Auto-organize references, and legacy Saved View tag compatibility remain. Production diff: 8 LOC deleted; test diff +2/-2. Flutter CI #2869 full green.
- **#962 / `245fe4ee…` — caller-zero Person-role removal path retired.** Removed `BookmarkRepository.removePersonFromBookmark(...)` and its sole downstream `AppDatabasePersonRoles.removePersonRole(...)`. Live Person-role reads, set-based mutation, and Stage1 batch mutation remain. Production diff: 16 LOC deleted. Flutter CI #2867 full green.
- **#958 / `51b83e06…` — caller-zero Person-group single-membership helpers retired.** Removed `PersonGroupStore.addPerson(...)` / `removePerson(...)`; test fixtures use canonical `setGroupsForPerson(...)`. Production diff: 16 LOC deleted.
- **#957 / `172add47…` — caller-zero Workspace observer helpers retired.** Removed `WorkspaceInfo.copyWith(...)` and `WorkspaceStore.watchWorkspaces()` while preserving live Workspace list/create/update/reorder/delete, active Workspace handling, Bookmark moves, and legacy Saved View compatibility. Production diff: 17 LOC deleted.
- **#952 / `5faa9496…` — legacy Saved View runtime Store modules retired.** Removed `SavedViewReadStore`, `SavedViewWriteStore`, their dead-only tests, and `SavedViewConfig`. Legacy `saved_views`, `saved_view_tags`, and `saved_view_workspace` remain compatibility data for `DatabaseViewStore.importLegacyBookmarkViews(...)`, Tag merge, backup, and migrations. Flutter CI #2852 full green.
- **#944 / `d705fd5c…` — caller-zero Bookmark Saved View / Workspace facades retired.** Removed the Saved View read/write facade from `BookmarkRepository` plus caller-zero Workspace convenience APIs. Production diff: 110 LOC deleted. Flutter CI #2842 full green.
- **#940 / `b42ca9bd…` — caller-zero Person role reverse query retired.** Removed `BookmarkRepository.watchRolesForPerson(...)` and its now-caller-zero `AppDatabasePersonRoles.watchRoleAssignmentsForPerson(...)`. Flutter CI #2831 full green.
- **#938 / `4f01eee6…` — legacy Bookmark-create Photo entry point retired.** Removed caller-zero `BookmarkImageRelationService.saveLegacyPhotosAfterCreate(...)`; canonical Image Relation write path retains fail-closed coverage. Flutter CI #2826 full green.
- **#915 / `545e07e1…` — legacy `AppDatabase` Bookmark↔Photo mutation helpers retired.** Removed five caller-zero mutation helpers while preserving compatibility reads/schema.
- **#903 / `48e945fd…` — legacy Bookmark Photo forwarding APIs retired.** Removed six caller-zero `BookmarkRepository` Photo mutation forwarders. Flutter CI #2748 full green.
- **#899 / `c6157b3a…` — Database-presentation compatibility shims completed.** Legacy Database-presentation imports are **0** and re-export shim files are **0**. Flutter CI #2737 full green.
- **#886 / `4469a549…` — legacy presentation raw-error allowlist completed at 0.** Flutter CI #2720 full green.

A failed deletion attempt remains important history:
- **#931 was closed, not merged.** Analyze exposed a missed live caller path `BookmarkRelationSection -> BacklinkRepository.link/unlink -> BookmarkRepository.addRelation/removeRelation`. Standing rule: code-search “definition only” is not sufficient proof; trace wrappers to real production hosts and let Analyze/full Test be the final caller-zero proof.

## Current measurable guardrails

`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended boundaries:
1. presentation direct `workspaceStore.database` reach-through remains guarded;
2. direct `AppDatabase` imports under canonical feature presentation remain guarded;
3. Database-presentation legacy shim imports: **0 maximum**;
4. Database-presentation re-export shim files: **0 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy `lib/views` / `lib/widgets` caught-error interpolation: **forbidden; allowlist size 0**.

Never relax a numeric ceiling, recreate a compatibility shim under a new filename, or reintroduce an error-privacy allowlist entry merely to land unrelated work.

## Completed compatibility tracks

### Presentation error privacy — complete
#812 originally froze eight legacy raw-error hosts. #886 completed the track at **8 -> 0 hosts**. Future work should enforce the zero boundary rather than reopen an allowlist unless a concrete product defect appears.

### Database presentation shims — complete
#868 moved Stage1 off legacy imports and #899 moved Generic to canonical `lib/features/database/presentation/widgets/` imports and deleted the final shims. The repository is **0 legacy Database-presentation imports / 0 shim files**.

### Legacy Saved View runtime API — retired; compatibility data retained
#944 removed the root Bookmark/Workspace Saved View facade. #952 then removed the now-caller-zero `SavedViewReadStore`, `SavedViewWriteStore`, and `SavedViewConfig` runtime layer.

Do **not** interpret that as permission to remove legacy Saved View tables. `DatabaseViewStore.importLegacyBookmarkViews(...)` still imports persisted legacy views into canonical Database Views, `TagGroupStore` still preserves Saved View tag references during merge, and backup/migrations still carry the old tables.

### Legacy Bookmark/Photo mutation narrowing — substantially reduced
Canonical Bookmark Image writes now go through Image Relations. Lane G removed caller-zero mutation entry points/forwarders in #903/#915/#938 while preserving compatibility reads, legacy schema/data, and the canonical Relation -> legacy projection still required by live Photo-era consumers.

Do **not** delete Photo CRUD/schema, `bookmark_photos`, Bookmark URL/thumbnail storage, or compatibility reads merely because some writers are gone. Retirement still requires caller-zero plus migration/import/export/backup parity and owning-lane product proof.

## Caller-zero policy

Fresh caller proof is required before every deletion:
1. search the symbol on current default branch;
2. trace wrappers/adapters to real production hosts;
3. inspect relevant tests that may represent a compatibility contract rather than disposable coverage;
4. keep schema/read/migration compatibility when only runtime APIs are caller-zero;
5. use Analyze and full Test as the final proof before merge.

Examples of deliberately retained live APIs from the latest audit:
- `BookmarkRepository.watchPersonRoles(...)` / `watchPersonRoleAssignments(...)` — used by Bookmark Person-role presentation;
- `setPeopleForRole(...)`, `batchAddPeople(...)`, `batchRemovePeople(...)` — live mutation paths;
- `watchBookmarksForPerson(...)`, `watchBookmarksForPhoto(...)`, `watchBookmarksForCollection(...)` — live management/backlink UI callers;
- `findDuplicateUrl(...)` — live create/import/Stage1 duplicate detection;
- `setBookmarkCollections(...)` and Collection CRUD — live Collection/transfer UI;
- `createTag(...)` — live Bookmark Property/Stage1 tag creation; canonical Tag Object bridge also uses the lower-level Tag persistence API;
- `TagGroupStore.watchTagGroupIds()`, `listGroups()`, usage stats, move/restore and mutation APIs — live Tag-management/service contracts after #963;
- `PersonGroupStore.memberIds()`, `groupsForPerson()`, `setGroupsForPerson()` and group CRUD — live People management/filter/edit contracts after #958;
- Photo CRUD / `watchPhotos()` and `PhotoReadStore.resolveRecord(...)` — live Photo management, Bookmark aggregation, and Object sync;
- `BookmarkAttachmentStore.initialize()/dispose()` — trivial bodies but live bootstrap/presentation lifecycle contract; broader host edits would buy little responsibility reduction;
- `PdfAnnotationStore.initialize()/dispose()` — no-op today but live viewer lifecycle calls; removing them would require a large host edit for negligible ownership reduction. The truly caller-zero synchronous list helper was removed in #968 instead;
- `BookmarkRepository.addRelation/removeRelation` — live through Backlink UI; #931 proved they are not dead.

Prefer deleting a real responsibility over introducing another pass-through abstraction just to improve a metric.

## Issue #225 remaining priorities

### P1 — GenericDatabasePage responsibility reduction
Still open and high-value:
- schema/database action workflows behind focused services/facades;
- layout-specific host extraction;
- Property-create/edit/dialog workflow extraction;
- further state/projection responsibility reduction where it measurably shrinks the page.

Existing progress includes `GenericDatabasePageStateLoader` and `GenericDatabasePageServices.fromWorkspaceStore(...)`. `GenericDatabasePage` remains a large conflict-prone hotspot. Do not force a broad extraction in the connector environment; prefer a patch-sized independent slice with a clear ownership window.

### P2 — dependency composition
Continue reducing presentation reach-through such as `repository.workspaceStore.database` only when a real application boundary removes responsibility. Do not add a facade whose only purpose is forwarding one existing call.

The post-#968 audit still finds presentation reach-through in large/shared hosts such as `app_shell.dart`, `people_management_page.dart`, `photo_management_page.dart`, `generic_database_page.dart`, `collection_management_page.dart`, and Stage1. Service/factory-layer database access is not itself the presentation violation. Prefer a naturally scoped host/service ownership change over a cosmetic forwarding wrapper.

### P2 — `AppDatabase` narrowing
Major responsibilities have already moved out. Continue only where a real caller-zero or responsibility-removal slice exists, with regression coverage. Historical migration semantics remain compatibility contracts.

### P1/P2 — legacy Bookmark convergence
Continue caller-zero retirement only as Primitive/Object/Relation lanes prove replacement parity. Track production references and deleted LOC rather than adapter count.

### Failure policy
The broad catch/privacy cleanup is complete and guarded. Reopen failure-policy work only for a concrete silent-corruption, privacy, or observability gap.

## Shared hotspots / ownership

Always re-check open PR changed files immediately before non-trivial edits to:
- `lib/views/generic_database_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/widgets/bookmark_reorderable_properties.dart`;
- `lib/views/people_management_page.dart`;
- `lib/views/settings_page.dart`;
- `lib/services/profile_manager.dart`;
- `lib/data/app_database.dart`.

At this checkpoint the visible open PRs #959/#956 are docs-only and do not touch Lane G handoff files or runtime hotspots, but that fact expires as soon as another PR opens or main advances.

## Cross-lane boundaries
- Lane A owns Object/ObjectType/Body and Object-owned presentation behavior.
- Lane B owns canonical Relation integrity, backlink/index/audit/reconcile and destructive Relation correctness.
- Lane C owns Database/View/schema/template product UX.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and media/import behavior.
- Lane E owns canonical Object search/indexing.
- Lane F owns Vault/filesystem lifecycle and delivery.
- Lane G may delete or narrow legacy paths only after replacement parity/ownership is established; never hide product changes inside refactor PRs.

## Validation

Local Flutter/Dart execution is unavailable in the connector environment; GitHub Flutter CI is the merge gate.

Recent validation checkpoints:
- #968: Flutter CI #2875 full green;
- #963: Flutter CI #2869 full green;
- #964: Flutter CI #2870 full green;
- #962: Flutter CI #2867 full green;
- #952: Flutter CI #2852 full green;
- #944: Flutter CI #2842 full green;
- #940: Flutter CI #2831 full green;
- #938: Flutter CI #2826 full green;
- #899: Flutter CI #2737 full green.

For caller-zero deletion, a green Analyze is especially important because it catches missed live callers that code search may not surface reliably (#931).

## Exact next actions
1. Start from current `main`; re-read Issue #225 and live open PR ownership.
2. Treat the obvious small G-owned Store/Repository caller-zero seam as substantially re-audited through #968. Re-open deletion work only when a fresh default-branch caller audit proves a real new candidate; do not manufacture tiny cleanups from live no-op lifecycle contracts.
3. If no new true deletion appears, select a patch-sized `GenericDatabasePage` P1 extraction or dependency-composition slice that **removes real responsibility/reach-through**, not a pass-through facade. Proceed only with a clear hotspot ownership window and a safe editing method; whole-file connector reconstruction risk is a valid reason to defer that particular slice.
4. Do not revisit the already-complete Database shim or broad error-privacy tracks; keep their zero guardrails intact.
5. Keep legacy Saved View tables and Photo/Bookmark compatibility storage/reads until their migration/import/export/backup and owning-lane retirement conditions are explicitly satisfied.
6. Continue to prefer independent small service/domain/test work if another lane leases a shared hotspot.
7. Refresh this handoff after the next material integration checkpoint; avoid publishing transient “no open PRs” claims as durable state.

## Risks / stop conditions
- Parallel lanes move `main` quickly; historical caller/ownership conclusions expire immediately.
- GitHub code-search indexing can lag; prefer direct current-ref file inspection for critical caller-zero decisions.
- Whole-file connector writes require exact-current-source preservation plus base-diff verification; do not accept unrelated formatting churn.
- Artificial/no-op CI-trigger commits are forbidden; use workflow rerun controls or the next meaningful change.
- Small caller-zero cleanup is now relatively sparse; do not turn live APIs/no-op lifecycle contracts into churn simply to keep Lane G busy.

Stop only when no independent safe Issue #225 slice remains, a genuine product/external blocker exists, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
