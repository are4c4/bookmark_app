# Broad catch / best-effort audit

Issue #225 requires reducing silent failure without breaking intentional best-effort behavior. A broad catch is not automatically a bug; the key question is whether failure is safe, expected, and observable enough for development/tests.

## Classification policy

- **fallback is the contract** — failure intentionally produces a deterministic fallback value. Keep broad catch when the boundary is genuinely untrusted; add tests/comments where useful.
- **best-effort enrichment** — the primary operation is already valid and optional enrichment may fail. Keep non-blocking behavior, but avoid a completely silent catch.
- **rollback / fail-closed** — catch exists to restore invariants and then rethrow/translate. Preserve the primary failure even when cleanup also fails.
- **user-visible failure** — catch already surfaces an error to UI. Prefer a stable domain/retry message over raw implementation exceptions.

## Production audit — refreshed 2026-09-07

| Path | Current pattern | Classification | Refactor action |
| --- | --- | --- | --- |
| `lib/widgets/global_file_drop_layer.dart` | PDF author creation is best-effort after bookmark/file import is already valid | best-effort enrichment | #227 made unexpected author-creation failure debug-visible; #321 aligned create/drop diagnostics and removed author names / exception text / URLs / paths. |
| `lib/widgets/bookmark_create_dialog.dart` | PDF author creation is optional enrichment | best-effort enrichment | #321 preserves successful import and emits fixed debug/test stack diagnostics without user content. |
| `lib/widgets/bookmark_attachment_section.dart` | attachment import is user-visible; PDF author creation is optional after bookmark metadata update | user-visible failure + best-effort enrichment | #364 replaced raw import exception interpolation with a stable retry message, added fixed operation + stack diagnostics, and kept author creation non-blocking/privacy-safe. The replacement deliberately avoided the public test-only seams from stale #336. |
| `lib/services/pdf_metadata_service.dart` | broad catch returns filename/title fallback | fallback is the contract | #274 keeps fallback and removes path/content from diagnostics. Keep non-blocking metadata behavior. |
| `lib/services/bookmark_metadata_service.dart` | broad catch returns metadata fallback | fallback is the contract | #279 keeps external-input fallback while avoiding URL/response/exception-text logging. |
| `lib/services/remote_image_storage_service.dart` | image geometry/decode failure does not invalidate stored media | best-effort enrichment | #237 makes geometry failure observable while preserving storage success; #404 keeps the fixed message + stack while removing the raw decode exception object. Existing behavior coverage proves undecodable bytes still import successfully without geometry. |
| `lib/services/weblink_create_enrichment_service.dart` | metadata fetch/persistence/preview enrichment occurs only after canonical Weblink identity is valid | best-effort enrichment | #393 preserves optional enrichment semantics while using fixed stage labels + stack traces and no raw exception object/request content. |
| `lib/data/generic_database_object_create_service.dart` | optional post-create Weblink enrichment runs after canonical Weblink creation | best-effort enrichment | #406 removes the raw exception object from debug diagnostics and adds a real regression proving an enrichment exception does not roll back the canonical Weblink. Fixed operation message + stack only. |
| `lib/services/object_sync_service.dart` | optional remote preview ingestion/schema setup must not block canonical Bookmark→Weblink sync | best-effort enrichment | #327 keeps canonical sync/startup and no-repeat retry policy unchanged while adding privacy-safe debug stack diagnostics for ingestion/setup failures. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility read/file checks fall back when Object mirroring/media is unavailable | fallback is the contract / compatibility bridge | Keep while Bookmark compatibility hosts remain; do not turn missing legacy/canonical media into user-visible failure. |
| `lib/services/weblink_visual_resolver.dart` | missing/unreadable managed media returns no visual | fallback is the contract | Keep read-only visual resolution fail-soft; file-existence failure is a normal fallback, not a logging target. |
| `lib/data/database_view_store.dart` | malformed persisted filters/sorts/settings JSON returns empty map/list | fallback is the contract | #234 added debug visibility; #328 removes attached `FormatException` so malformed persisted user JSON cannot be echoed into diagnostics. Fixed message + stack only. |
| `lib/data/tag_group_store.dart` | malformed persisted tag-tree expansion JSON returns default collapsed state | fallback is the contract | #325 keeps the same state while making malformed/non-map values debug-visible without stored JSON or exception text. |
| `lib/data/generic_database_page_state_loader.dart` | formula/rollup evaluation failure projects `null` and page loading continues | fallback is the contract | #326 preserves the null projection and adds fixed debug stack visibility without Object titles, Property names/expressions or exception text. |
| `lib/data/generic_database_store.dart` | malformed Property config JSON -> `{}`; malformed Record value JSON -> `null` | fallback is the contract | #329 adds privacy-safe debug visibility and focused persisted-corruption coverage without logging raw config/value/exception text. |
| `lib/data/object_board_create_service.dart` | grouped-preset failure rolls back newly-created Object | rollback / fail-closed | #351 makes rollback cleanup explicitly secondary so delete failure cannot replace the original create/preset failure; diagnostics contain no Object/Property/user content. |
| Image import/create rollback boundary | copied managed file cleanup may also fail after the canonical Image operation failed | rollback / fail-closed | #358 preserves the original Image import/create failure and treats cleanup failure as privacy-safe secondary diagnostics. |
| `lib/services/profile_backup_service.dart` | restore/import failure cleans partial target | rollback / fail-closed | #362 preserves the primary restore/import failure when target cleanup also fails; cleanup remains best-effort and privacy-safe. |
| `lib/services/profile_manager.dart` | corrupt registry can fail soft to default Profile; imported metadata is advisory | fallback is the contract, **higher risk** | #363 removes raw exception interpolation from fallback diagnostics while leaving selection/recovery semantics unchanged. Changing which Profile/data location is selected still requires explicit product/data-safety policy. |
| `lib/views/global_search_page.dart` | search/index failures use a stable retry-oriented state | user-visible failure | #331 replaced raw caught-Object rendering while preserving rebuild retry behavior. |
| `lib/views/settings_page.dart` / backup section | backup/settings operation failures use stable messages | user-visible failure | #332/#333/#335 stabilize backup, AutoOrganize and malformed View-opening settings; #374 extracts backup workflow and #400 moves database composition behind `DatabaseBackupService.fromRepository(...)` without changing error behavior. |
| `lib/main.dart` | bootstrap/Profile-switch failure remains fail-closed; rollback to previous Profile is preserved | user-visible / fail-closed initialization | #368 replaced raw fatal-screen exception interpolation with one stable retry-oriented message and fixed debug operation labels + stack traces. Original error state and rollback semantics remain unchanged; Profile/path/exception text is not logged. |
| `lib/features/database/presentation/widgets/database_property_add_popover_host.dart` | Property authoring failure is user-visible and must not expose storage/domain exception text | user-visible failure | #701 adds a real widget failure regression, replaces raw exception interpolation with a stable retry message, and keeps debug observability to a fixed operation label + stack trace. Property/Relation persistence stays on the existing canonical authoring service. |

## Current policy

1. **Do not convert intentional fail-soft behavior into user-visible failure** merely to eliminate a broad catch.
2. **Rollback cleanup must never replace the primary failure** that triggered rollback. Cleanup failures are secondary diagnostics unless a product contract explicitly says otherwise.
3. **Stable user messages beat raw exception rendering.** Database/HTTP/filesystem exception strings can expose implementation details or user data and are rarely actionable to end users.
4. **Debug observability must be privacy-safe.** Prefer fixed operation/stage labels plus stack traces. Avoid raw names, URLs, file paths, JSON, response bodies, bytes, credentials and exception text when those may echo user content.
5. **Normal compatibility fallbacks should remain quiet** unless there is evidence of a debugging gap. File-not-found/no-media fallback is not automatically an error.
6. **Recovery semantics are separate from diagnostic cleanup.** In particular, `ProfileManager` corrupt-registry fallback selection affects data-location recovery and must not be changed as a routine catch cleanup.

## Refactor order

The highest-value small silent/privacy boundaries have largely been covered. New failure-policy work should therefore be selective:

1. prefer measurable responsibility/LOC reduction or real legacy caller retirement over another isolated logging PR;
2. fix remaining raw user-visible implementation exception interpolation when it is in a small, independently testable/owned host;
3. replace repeated exception parsing only when a real typed/domain boundary deletes caller duplication;
4. address genuinely silent failures when they can hide corruption while the product safely continues.

Current raw user-visible exception interpolation is concentrated in large/shared legacy hosts such as Photo management, Tag management and Stage1. Do not rewrite those hosts merely to remove one string. Handle the error boundary when a safe, focused host slice already owns the file and can add a real regression.

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
- Do not display raw database/HTTP/filesystem exception strings when a stable domain message exists.
- Do not add noisy logs to ordinary file-not-found / no-media compatibility fallbacks simply to make every catch observable.
- When rollback itself fails, preserve the original operation failure and treat cleanup failure as secondary diagnostics unless recovery semantics require otherwise.
- Do not add public production constructor/test seams solely to force a Widget failure-path regression when a smaller deterministic contract guard can prove the policy without lifecycle instability.
