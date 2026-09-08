# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, measurable dependency reduction, `AppDatabase` narrowing, failure/privacy policy guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

Latest `main` at this handoff: **`d705fd5c539a9274c024a36a155a2e4197e037b5`** (`#944`).

Current open PR audit at this checkpoint:
- **#943 — Lane D**, Bookmark detail/Weblink URL presentation. It does not own the data files changed by #944, but re-check its changed files before any Bookmark detail/attachment work.
- **#946 — Lane A docs-only**, Object handoff refresh. It does not own Lane G runtime files.

Lane G merged #944 after green Analyze/full Test, then re-audited current small Store/Service candidates. The first follow-up candidates inspected (`DatabaseViewGroupAdapter`, `DatabaseViewTabOverflowPolicy`, `AppSettingsService`, Bookmark Image Relation factory, Image/PDF service boundaries) all still have production callers or are live canonical composition dependencies, so they were deliberately retained rather than turned into speculative cleanup. There is no active Lane G runtime branch at this checkpoint; `docs/refactor-handoff-after-944` only refreshes durable documentation.

## Latest integrated Lane G checkpoints

Recent integration sequence:
- **#944 / `d705fd5c…` — caller-zero Bookmark Saved View + Workspace facades retired.** Removed four Saved View forwarding APIs and their read/write fields from `BookmarkRepository`, plus caller-zero `WorkspaceStore` Saved View/workspace helper APIs. The only test fixture that used the forwarding API now writes through `SavedViewWriteStore` directly. Production diff: **110 LOC deleted** across the two data boundaries. `analyze-test` completed successfully before squash merge.
- **#940 / `b42ca9bd…` — caller-zero Person role reverse query retired.** Removed `BookmarkRepository.watchRolesForPerson(...)` and its now-caller-zero `AppDatabasePersonRoles.watchRoleAssignmentsForPerson(...)`; live Bookmark -> Person role reads remain unchanged. Production diff: 15 LOC deleted. Flutter CI #2831 full green.
- **#938 / `4f01eee6…` — legacy Bookmark-create Photo entry point retired.** Removed caller-zero `BookmarkImageRelationService.saveLegacyPhotosAfterCreate(...)`; production service diff deleted 116 LOC. The important corrupt-Cover fail-closed regression moved to canonical `saveImagesAfterCreate(...)`. Flutter CI #2826 full green.
- **#915 / `545e07e1…` — legacy `AppDatabase` Bookmark↔Photo mutation helpers retired.** Removed five caller-zero mutation helpers after the only test fixture caller was converted to direct legacy-row fixture setup. Production diff: 42 LOC deleted; legacy compatibility reads/schema remain.
- **#903 / `48e945fd…` — legacy Bookmark Photo forwarding APIs retired.** Removed six caller-zero `BookmarkRepository` Photo mutation forwarders after canonical Image Relation migration. Production diff: 9 LOC deleted. Flutter CI #2748 full green.
- **#899 / `c6157b3a…` — final Database-presentation compatibility shims retired.** Legacy Database presentation imports **22 -> 0** and re-export shim files **5 -> 0**; CI ceilings fixed at zero. Flutter CI #2737 full green.
- **#886 / `4469a549…` — presentation raw-error cleanup completed.** Legacy raw-error host allowlist **8 -> 0**. Flutter CI #2720 full green.
- **#882 / `7ff4e273…` — five dead `BookmarkRepository` Workspace/Tag forwarders retired.** Flutter CI #2688 full green.
- **#875 / `f2d54ad…`**, **#872 / `51420bab…`**, **#870 / `a18ce533…`**, **#867 / `4fb55d3…`**, **#863 / `84350e59…`** — focused error-privacy ratchets that reduced the legacy presentation allowlist to zero while preserving typed/domain messages where useful.
- **#868 / `c55146f…`** — Stage1 legacy Database-presentation imports retired before #899 closed the remaining Generic imports/shims.
- **#829 / `6fffec0d…`** — caller-zero Weblink detail preview retired.
- **#795 / `ecffd5b2…`** — Generic Database Relation-record reload fanout bounded.
- **#735 / `60d6ac5a…`** — caller-zero Database toolbar re-export shim retired.

A failed deletion attempt is also important history:
- **#931 was closed, not merged.** Analyze exposed a missed live caller path `BookmarkRelationSection -> BacklinkRepository.link/unlink -> BookmarkRepository.addRelation/removeRelation`. Treat this as a standing rule: code-search “definition only” is not sufficient proof; trace wrappers/real hosts and let Analyze/full Test be the final caller-zero proof.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended boundaries:
1. presentation direct `workspaceStore.database` reach-through: guarded ceiling remains in CI;
2. direct `AppDatabase` imports under canonical feature presentation: guarded ceiling remains in CI;
3. Database-presentation legacy shim imports: **0 maximum**;
4. Database-presentation re-export shim files: **0 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy `lib/views` / `lib/widgets` caught-error interpolation: **forbidden; allowlist size 0**.

Never relax a numeric ceiling, recreate a compatibility shim under a new filename, or reintroduce an error-privacy allowlist entry merely to land unrelated work.

## Completed compatibility tracks

### Presentation error privacy — complete
#812 originally froze eight legacy raw-error hosts. #886 completed the track at **8 -> 0 hosts**. Future work should enforce the zero boundary rather than reopen an allowlist unless a genuinely new product defect appears.

### Database presentation shims — complete
#868 moved Stage1 off the legacy imports. #899 moved Generic to canonical `lib/features/database/presentation/widgets/` imports and deleted the final three one-line `lib/widgets/` shims. The repository is now **0 legacy Database-presentation imports / 0 shim files**; historical names remain guarded so they cannot return.

### Legacy Bookmark/Photo mutation narrowing — substantially reduced
Canonical Bookmark Image writes now go through Image Relations. Lane G removed caller-zero mutation entry points/forwarders in #903/#915/#938 while preserving compatibility reads, legacy schema/data, and the canonical Relation -> legacy projection still needed by live Photo-era consumers.

Do **not** delete Photo CRUD/schema, `bookmark_photos` rows, Bookmark URL/thumbnail storage, or compatibility reads merely because some writers are gone. Retirement still requires caller-zero plus migration/import/export/backup parity and owning-lane product proof.

## Caller-zero policy

Fresh caller proof is required before every deletion:
1. search the symbol on current default branch;
2. trace any wrappers/adapters to real production hosts;
3. inspect relevant tests that may represent a compatibility contract rather than disposable coverage;
4. keep schema/read compatibility when only write APIs are caller-zero;
5. use Analyze and full Test as the final proof before merge.

Examples of deliberately retained live APIs from the latest audit:
- `BookmarkRepository.watchPersonRoles(...)` / `watchPersonRoleAssignments(...)` — used by Bookmark Person-role presentation;
- `watchBookmarksForPerson(...)`, `watchBookmarksForPhoto(...)`, `watchBookmarksForCollection(...)` — live management/backlink UI callers remain;
- Photo CRUD / `watchPhotos()` — `PhotoManagementPage` and compatibility hosts still use them;
- `BookmarkAttachmentStore.initialize()/dispose()` — bodies are currently trivial/no-op but live presentation code treats them as lifecycle contract; deleting them would require broader host edits for little responsibility reduction;
- `BookmarkRepository.addRelation/removeRelation` — live through Backlink UI; #931 proved they are not dead;
- current View policy/adapters and primitive media/PDF services inspected after #944 — live production composition remains, so do not delete them based on names such as “compatibility” alone.

Prefer deleting a real responsibility over introducing another pass-through abstraction just to improve a metric.

## Issue #225 remaining priorities

### P1 — GenericDatabasePage responsibility reduction
Still open and high-value:
- page state/loading/computed projection extraction;
- schema/database action workflows (identity edit, duplicate, delete, collection settings) behind focused services/facades;
- layout-specific host extraction;
- Property-edit/dialog workflow extraction.

`GenericDatabasePage` remains a large conflict-prone hotspot. In the connector environment, whole-file writes are risky for tiny edits, so do not force a broad extraction merely to keep Lane G busy. Prefer a patch-sized independent slice when a safe editing path and ownership window exist.

### P2 — dependency composition
Continue reducing presentation reach-through such as `repository.workspaceStore.database` when a real application facade can remove responsibility. Do not add a facade whose only purpose is forwarding one existing call.

The post-#944 audit still finds live reach-through in known hotspots/management hosts. Prior audits already rejected wrapper-only `DatabaseViewStore` composition for Photo/People/Collection because it would hide the metric without reducing responsibility; keep that decision unless a meaningful existing boundary changes the equation.

### P2 — `AppDatabase` narrowing
Major responsibilities have already moved out. Continue only where a real caller-zero or responsibility-removal slice exists, with regression coverage. Historical migration semantics remain compatibility contracts.

### P1/P2 — legacy Bookmark convergence
Continue caller-zero retirement as Primitive/Object/Relation lanes prove replacement parity. Track production references and deleted LOC rather than adapter count.

### Failure policy
The highest-value broad catch/privacy work is already covered and documented in `docs/ERROR_POLICY_AUDIT.md`. Prefer responsibility reduction/caller-zero deletion now; only reopen failure-policy work for a concrete silent-corruption or observability gap.

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

At this checkpoint, open runtime PR **#943** is Lane D and owns Bookmark detail/attachment URL presentation; open **#946** is Lane A docs-only. Neither currently owns the Lane G data boundaries changed by #944. This fact is time-sensitive and must not be reused without a fresh audit.

## Cross-lane boundaries
- Lane A owns Object/ObjectType/Body and Object-owned presentation behavior.
- Lane B owns canonical Relation integrity, backlink/index/audit/reconcile and destructive Relation correctness.
- Lane C owns Database/View/schema/template product UX.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and media/import behavior.
- Lane E owns canonical Object search/indexing.
- Lane F owns Vault/filesystem lifecycle and delivery.
- Lane G may delete or narrow legacy paths only after replacement parity/ownership is established; never hide product changes inside refactor PRs.

## Validation
Local Flutter/Dart execution is unavailable in this connector environment; GitHub Flutter CI is the merge gate.

Recent validation checkpoints:
- #944: `analyze-test` success before squash merge.
- #940: Flutter CI #2831 full green.
- #938: Flutter CI #2826 full green.
- #903: final Flutter CI #2748 full green.
- #899: final Flutter CI #2737 full green.
- #886: final Flutter CI #2720 full green.

For caller-zero deletion, a green Analyze is especially important because it catches missed live callers that code search may not surface reliably (#931).

## Exact next actions
1. Start from current `main`; re-read Issue #225 and live open PR ownership because #943/#946 may have merged or changed.
2. Continue fresh caller-zero audit in small Store/Repository/Service boundaries. Delete only when wrapper-to-real-host tracing plus Analyze can prove zero callers; do not repeat already-rejected live candidates from the post-#944 audit without new evidence.
3. If no true deletion exists, select a patch-sized `GenericDatabasePage` P1 extraction that removes real responsibility without adding a pass-through layer; defer if hotspot ownership or connector whole-file risk makes the slice unsafe.
4. Re-audit presentation/database reach-through for a focused composition improvement only where an application facade genuinely removes low-level construction. Do not create wrappers solely to ratchet the metric.
5. Keep Photo/Bookmark compatibility storage and reads until the owning product lane proves full replacement parity.
6. Keep `docs/LEGACY_BOOKMARK_INVENTORY.md` synchronized with integrated retirements; this handoff branch reconciles the stale Database-presentation shim narrative with #899 and records #944.
7. Update Issue #225 and this handoff after the next material integration checkpoint.

## Risks / stop conditions
- Parallel lanes move `main` quickly; historical caller/ownership conclusions expire immediately.
- GitHub code-search indexing can lag; prefer direct current-ref file inspection for critical caller-zero decisions.
- Whole-file connector writes require exact-current-source preservation plus base-diff verification; do not accept unrelated formatting churn.
- Artificial/no-op CI-trigger commits are forbidden; use workflow rerun controls or the next meaningful change.

Stop only when no independent safe Issue #225 slice remains, a genuine product/external blocker exists, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
