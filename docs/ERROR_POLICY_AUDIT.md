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
| `lib/widgets/global_file_drop_layer.dart` | PDF author creation is best-effort after bookmark/file import is already valid | best-effort enrichment | #227 made unexpected author-creation failure debug-visible; #321 aligned create/drop diagnostics and removed author names / exception text / URLs / paths. |
| `lib/widgets/bookmark_create_dialog.dart` | PDF author creation is optional enrichment | best-effort enrichment | #321 preserves successful import and emits fixed debug/test stack diagnostics without user content. |
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
| `lib/services/profile_manager.dart` | decode failure can fall back to default profile state | fallback is the contract, **higher risk** | Debug visibility exists, but behavior changes are deferred. This path can affect data-location recovery and requires an explicit recovery/product policy before changing fallback selection or persistence. |
| `lib/views/global_search_page.dart` | search/index catch stores the caught Object and renders it via `message: '$_error'` | user-visible failure | **Known next candidate.** Replace with a focused, testable stable-error state while preserving indexing/search retry behavior; do not make an untested one-line cosmetic substitution. |
| `lib/views/settings_page.dart` | backup/settings operation catches may surface implementation errors | user-visible failure | Lower priority than silent persistence corruption; move toward stable domain messages when the service/error boundary is touched. |
| `lib/main.dart` | initialization catch stores `_error` and fails visibly rather than continuing partially | user-visible/fail-closed initialization | Keep fail-closed startup. Audit message exposure separately if raw exception details are rendered. |

## Refactor order

1. Silent best-effort/persisted-data failures where the primary operation can safely continue — most known high-value cases now have privacy-safe debug visibility.
2. Broad catches that may hide profile/data-location corruption — **do not change recovery behavior without explicit policy**.
3. Raw user-visible implementation exceptions — introduce stable domain/error-state boundaries with tests preserving retry/failure behavior.
4. Repeated parsing of database constraint exceptions in Widgets — translate at Store/Service boundaries when a real repeated caller is simplified.
5. Stable normal fallbacks such as file-existence checks should remain quiet unless evidence shows a debugging gap; reducing `catch` counts is not itself a goal.

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
