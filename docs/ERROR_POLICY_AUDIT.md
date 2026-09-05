# Broad catch / best-effort audit

Issue #225 requires reducing silent failure without breaking intentional best-effort behavior. A broad catch is not automatically a bug; the key question is whether failure is safe, expected, and observable enough for development/tests.

## Classification policy

- **fallback is the contract** — failure intentionally produces a deterministic fallback value. Keep broad catch only when the boundary is genuinely untrusted; add tests/comments where useful.
- **best-effort enrichment** — the primary operation is already valid and optional enrichment may fail. Keep non-blocking behavior, but avoid a completely silent catch.
- **rollback / fail-closed** — catch exists to restore invariants and then rethrow/translate. Preserve rollback semantics.
- **user-visible failure** — catch already surfaces a stable error to UI. Prefer domain errors over raw implementation exceptions when practical.

## Initial production audit — 2026-09-05

| Path | Current pattern | Classification | Refactor action |
| --- | --- | --- | --- |
| `lib/widgets/global_file_drop_layer.dart` | PDF author creation is best-effort after the bookmark/file import is already valid | best-effort enrichment | PR #227 made unexpected author-creation failure debug-visible; PR #321 keeps that visibility while removing author names and exception text from diagnostics. |
| `lib/widgets/bookmark_create_dialog.dart` | empty `catch (_) {}` while creating PDF authors | best-effort enrichment | PR #321 preserves successful import and adds debug/test-only stack diagnostics without logging author names, exception text, URLs or paths. |
| `lib/services/pdf_metadata_service.dart` | broad catch returns filename/title fallback | fallback is the contract | Keep non-blocking metadata fallback; add focused malformed/tool-failure test if coverage is missing. |
| `lib/services/bookmark_metadata_service.dart` | broad catch returns metadata fallback | fallback is the contract | Keep; metadata fetch/parse is untrusted external input. Prefer test proving fallback fields remain stable. |
| `lib/services/remote_image_storage_service.dart` | image decode catch sets decoded image to null | best-effort enrichment | Keep storage flow independent of dimension decode; document/test that missing geometry is safe. |
| `lib/services/object_sync_service.dart` | thumbnail ingestion catch does not block canonical Bookmark→Weblink sync | best-effort enrichment | Correct high-level policy; retain comment and add debug/test visibility only if failures are otherwise opaque. Do not turn preview ingestion into sync failure. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility read catch falls back when Object mirroring is unavailable | fallback is the contract / compatibility bridge | Keep while old installations may lack mirrored Object state; remove with compatibility path, not earlier. |
| `lib/services/weblink_visual_resolver.dart` | compatibility/read fallback catches | fallback is the contract | Keep read-only visual resolution fail-soft; tests should cover no-media/missing-relation cases. |
| `lib/data/database_view_store.dart` | settings decode catch returns empty map | fallback is the contract | Keep only for corrupt/old settings tolerance; consider debug visibility if malformed persisted JSON can indicate a regression. |
| `lib/data/tag_group_store.dart` | malformed persisted tag-tree expansion JSON returns the default collapsed state | fallback is the contract | #225 follow-up keeps the same fail-soft state while making malformed/non-map persisted values debug-visible without logging stored JSON or exception text. |
| `lib/data/object_board_create_service.dart` | catch rolls back newly-created Object | rollback / fail-closed | Preserve exactly; this protects invariants. Ensure original failure is rethrown/translated after rollback. |
| `lib/services/profile_backup_service.dart` | catch cleans partial target | rollback / fail-closed | Preserve cleanup semantics; avoid swallowing the original failure after cleanup. |
| `lib/services/profile_manager.dart` | broad catch falls back to default profile state | fallback is the contract, higher risk | Audit separately because profile-state corruption can hide data-location problems; fallback must not silently point users at a different profile. |
| `lib/views/settings_page.dart` | catches backup/settings operation and shows UI error | user-visible failure | Lower priority; move toward stable domain messages when touching the service boundary. |
| `lib/views/global_search_page.dart` | catches search error and handles mounted UI state | user-visible failure | Lower priority than empty catches; avoid raw implementation exception text if currently surfaced. |
| `lib/main.dart` | initialization catch stores `_error` | user-visible/fail-closed initialization | Keep; app initialization must not silently continue with partial state. |

## Refactor order

1. Empty catches in production where the primary operation can safely continue.
2. Broad catches that may hide profile/data-location corruption.
3. Repeated parsing of database constraint exceptions in Widgets; translate at Store/Service boundaries.
4. Stable fallback boundaries (metadata/image decode/settings JSON) only when a test or debug signal is missing.

## Guardrails

- Never make optional Weblink thumbnail/image ingestion block canonical Object/Relation sync merely to eliminate a broad catch.
- Never remove rollback catches around newly-created Objects/partial backup targets.
- Prefer debug-only visibility for expected best-effort failure when user action does not need to fail.
- Prefer typed/domain errors for actionable user failures.
- Do not display raw database/HTTP exception strings when a stable domain message exists.
