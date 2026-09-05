# Broad catch / best-effort audit

Issue #225 requires reducing silent failure without breaking intentional best-effort behavior. A broad catch is not automatically a bug; the key question is whether failure is safe, expected, and observable enough for development/tests.

## Classification policy

- **fallback is the contract** — failure intentionally produces a deterministic fallback value. Keep broad catch only when the boundary is genuinely untrusted; add tests/comments where useful.
- **best-effort enrichment** — the primary operation is already valid and optional enrichment may fail. Keep non-blocking behavior, but avoid a completely silent catch.
- **rollback / fail-closed** — catch exists to restore invariants and then rethrow/translate. Preserve rollback semantics.
- **user-visible failure** — catch already surfaces an error to UI. Prefer a stable domain message over raw implementation exceptions.

## Production audit — refreshed 2026-09-06

| Path | Current pattern | Classification | Refactor action |
| --- | --- | --- | --- |
| `lib/widgets/global_file_drop_layer.dart` | dropped PDF/video import is primary; PDF author creation is optional after a valid import | user-visible failure / best-effort enrichment | #321 made author enrichment privacy-safe; #338 replaced raw top-level import exception text with a stable retry message while preserving drop/import semantics. |
| `lib/widgets/bookmark_create_dialog.dart` | URL/file Bookmark creation is actionable; PDF author creation is optional enrichment | user-visible failure / best-effort enrichment | #321 made author enrichment privacy-safe; #337 replaced raw URL/file creation errors with stable retry messages and focused deterministic coverage. |
| `lib/widgets/bookmark_attachment_section.dart` | attachment import is actionable; PDF author creation is optional after metadata update | user-visible failure / best-effort enrichment | #336 is the current focused PR: stable import failure message, fixed debug diagnostics, and observable-but-non-blocking author failure. Production storage/metadata semantics stay unchanged. |
| `lib/services/pdf_metadata_service.dart` | broad catch returns filename/title fallback | fallback is the contract | #274 keeps fallback and removes path/content from diagnostics. Keep non-blocking metadata behavior. |
| `lib/services/bookmark_metadata_service.dart` | broad catch returns metadata fallback | fallback is the contract | #279 keeps external-input fallback while avoiding URL/response/exception-text logging. |
| `lib/services/remote_image_storage_service.dart` | image geometry/decode failure does not invalidate stored media | best-effort enrichment | #237 makes geometry failure observable while preserving storage success. |
| `lib/services/object_sync_service.dart` | optional remote preview ingestion/schema setup must not block canonical Bookmark→Weblink sync | best-effort enrichment | #327 keeps canonical sync/startup and no-repeat retry policy unchanged while adding privacy-safe debug stack diagnostics for ingestion/setup failures. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility read/file checks fall back when Object mirroring/media is unavailable | fallback is the contract / compatibility bridge | Keep while Bookmark compatibility hosts remain; do not turn missing legacy/canonical media into user-visible failure. |
| `lib/services/weblink_visual_resolver.dart` | missing/unreadable managed media returns no visual | fallback is the contract | Keep read-only visual resolution fail-soft; file-existence failure is a normal fallback, not a logging target. |
| `lib/data/database_view_store.dart` | malformed persisted filters/sorts/settings JSON returns empty map/list | fallback is the contract | #234 added debug visibility; #328 removes attached `FormatException` so malformed persisted user JSON cannot be echoed into diagnostics. Fixed message + stack only. |
| `lib/data/tag_group_store.dart` | malformed persisted tag-tree expansion JSON returns default collapsed state | fallback is the contract | #325 keeps the same state while making malformed/non-map values debug-visible without stored JSON or exception text. |
| `lib/data/generic_database_page_state_loader.dart` | formula/rollup evaluation failure projects `null` and page loading continues | fallback is the contract | #326 preserves the null projection and adds fixed debug stack visibility without Object titles, Property names/expressions or exception text. |
| `lib/data/generic_database_store.dart` | malformed Property config JSON -> `{}`; malformed Record value JSON -> `null` | fallback is the contract | #329 adds privacy-safe debug visibility and focused persisted-corruption coverage without logging raw config/value/exception text. |
| `lib/data/object_board_create_service.dart` | catch rolls back newly-created Object | rollback / fail-closed | Preserve exactly; this protects invariants. Ensure original failure is rethrown/translated after rollback. |
| `lib/services/profile_backup_service.dart` | catch cleans partial target | rollback / fail-closed | Preserve cleanup semantics; avoid swallowing the original failure after cleanup. |
| `lib/services/profile_manager.dart` | profile-registry decode can fail soft to the default profile; imported profile metadata is advisory | fallback is the contract, **higher risk recovery** | Recovery selection/persistence remains deferred. #340 is the current privacy-only PR removing raw exception text from debug diagnostics while preserving the exact fallback behavior and stack visibility. |
| `lib/views/global_search_page.dart` | index/search failures need retry without exposing implementation details | user-visible failure | #330 introduced one stable retryable error boundary for both index and query failures with Widget regressions. Complete for the audited path. |
| `lib/views/settings_page.dart` | backup export/restore failures are actionable | user-visible failure | #331 preserves restore confirmation and backup behavior while replacing raw implementation errors with stable messages and privacy-safe diagnostics. |
| `lib/views/auto_organize_settings_section.dart` | rule create/bulk-apply failures are actionable | user-visible failure | #332 replaces raw implementation errors with stable messages while preserving rule/application semantics. |
| Database View open-mode decoding | malformed persisted open mode must fail closed to inherited/default behavior | fallback / user-visible configuration | #335 removes raw parse details from the View open-mode boundary and keeps the existing fallback semantics. |
| `lib/main.dart` | initialization/profile-switch failure is fail-closed and can retain a caught Object for presentation | user-visible / fail-closed initialization | Keep fail-closed startup. Audit presentation privacy separately; do not change recovery/fallback sequencing casually. |

## Remaining raw user-visible error candidates

The latest default-branch code search still identifies raw exception interpolation in several live hosts. Search indexing can lag fresh merges, so verify the exact file on current `main` before editing.

High-value candidates include:
- `lib/views/image_editor_page.dart` — image save/edit failure;
- `lib/views/photo_management_page.dart` — photo import failure;
- `lib/widgets/bookmark_detail_panel.dart` — inline Bookmark save failure;
- `lib/views/object_inspector_page.dart` — several Object-detail mutation failures;
- `lib/views/app_shell.dart` — workspace/database action failures;
- `lib/views/tag_management_page.dart` — tag/group edit failures;
- `lib/views/bookmark_unified_stage1_page.dart` — compatibility URL-add failure;
- `lib/views/generic_database_page.dart` — multiple schema/layout/mutation failure surfaces.

Prefer small files and deterministic Widget seams first. Do not hand-reconstruct a large shared hotspot solely to make a one-line message change.

## Refactor order

1. Finish currently isolated failure/privacy slices (#336 and #340) after green validation.
2. Continue raw user-visible implementation-error cleanup where a focused stable state/message can be regression-tested without broad host churn.
3. Continue GenericDatabasePage P1 responsibility extraction only when a safe patch-sized editing path exists; Property create/edit workflow remains a high-value candidate.
4. Keep ProfileManager **recovery behavior** deferred until an explicit data-recovery/product policy exists; diagnostic sanitization does not authorize changing fallback selection.
5. Translate database constraint failures into typed/domain errors when doing so removes real repeated caller parsing; reducing catch/string counts by itself is not a goal.
6. Stable normal fallbacks such as ordinary file-not-found/no-media checks should remain quiet unless evidence shows a debugging gap.

## Diagnostic privacy rule

Debug/test observability must not create a secondary user-data leak. Prefer:
- fixed operation/stage message;
- stack trace when useful;
- no raw exception object when it can echo persisted/request content;
- no names, URLs, file paths, raw JSON, response bodies, bytes, credentials or secrets unless a separate diagnostic design explicitly sanitizes them.

## Guardrails

- Never make optional Weblink thumbnail/image ingestion block canonical Object/Relation sync merely to eliminate a broad catch.
- Never remove rollback catches around newly-created Objects/partial backup targets.
- Prefer debug-only visibility for expected best-effort failure when user action does not need to fail.
- Prefer typed/domain errors for actionable user failures.
- Do not display raw database/HTTP exception strings when a stable domain message exists.
- Do not add noisy logs to ordinary file-not-found / no-media compatibility fallbacks simply to make every catch observable.
- Profile registry fallback can affect data location; privacy-only diagnostic changes are allowed, but recovery semantics require separate policy.
