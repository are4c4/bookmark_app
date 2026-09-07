# Feature presentation error privacy

Presentation code must not turn raw caught exceptions into interpolated user-visible strings.

This is a regression boundary, not a blanket ban on exception handling. Code may still:

- catch an error and map it to a stable user-safe message;
- forward the typed error through a callback such as `onError(error)`;
- emit privacy-safe diagnostics that do not interpolate exception text;
- use raw strings or escaped dollar signs when they are literal text rather than Dart interpolation.

`tool/feature_presentation_error_privacy_guard.sh` scans catch bodies in canonical `lib/features/**/presentation/` and legacy `lib/views/` / `lib/widgets/` presentation. It fails when the caught variable is interpolated as `$error`, `${error...}`, or the equivalent for another catch variable.

Issue #225 originally froze legacy raw-error debt to an explicit allowlist of eight hosts. Focused cleanup retired every entry:

- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/tag_management_page.dart`;
- `lib/views/generic_database_page.dart`.

The legacy allowlist is now **empty**. Raw caught-error interpolation is therefore rejected in both canonical feature presentation and the legacy presentation roots. Do not add a host back to the allowlist to land unrelated work; map failures to a stable domain/retry message or move typed handling to the appropriate Store/Service boundary.

The guard remains wired into Flutter CI. `tool/feature_presentation_error_privacy_guard_test.sh` covers safe forwarding/escaping, canonical rejection, rejection of the former Generic Database host after the zero-ratchet, and rejection of any new legacy host.

Stable user messages should remain operation-oriented rather than exposing database, HTTP, filesystem, persisted-value, URL, path, or other implementation exception text. Diagnostic observability is a separate concern and should remain privacy-safe.
