#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/feature_presentation_error_privacy_guard.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-feature-error-privacy-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p \
  "$fixture/lib/features/object/presentation/widgets" \
  "$fixture/lib/features/object/application" \
  "$fixture/lib/views" \
  "$fixture/lib/widgets"

cat > "$fixture/lib/features/object/presentation/widgets/safe_forwarding.dart" <<'EOF'
Future<void> runSafe(void Function(Object error) onError) async {
  try {
    throw StateError('private-value');
  } catch (error) {
    onError(error);
    final rawExample = r'$error';
    final escapedExample = '\$error';
    // '$error' in a comment is not rendered.
    if (rawExample.isEmpty || escapedExample.isEmpty) return;
  }
}
EOF

cat > "$fixture/lib/features/object/application/outside_presentation.dart" <<'EOF'
Future<void> applicationBoundary() async {
  try {
    throw StateError('application-only');
  } catch (error) {
    final diagnostic = 'application: $error';
    if (diagnostic.isEmpty) return;
  }
}
EOF

output="$(cd "$fixture" && bash "$script")"
grep -Fq 'feature_presentation_error_privacy_guard: PASS' <<<"$output"

cat > "$fixture/lib/views/generic_database_page.dart" <<'EOF'
Future<void> formerLegacyHost() async {
  try {
    throw StateError('legacy-private-value');
  } catch (error) {
    final message = 'Former legacy debt: $error';
    if (message.isEmpty) return;
  }
}
EOF

set +e
former_legacy_failure="$(cd "$fixture" && bash "$script" 2>&1)"
former_legacy_status=$?
set -e

if [[ "$former_legacy_status" -ne 1 ]]; then
  echo "Expected former Generic legacy host to exit 1, got $former_legacy_status" >&2
  exit 1
fi
grep -Fq 'Caught exception interpolation spread into a new legacy presentation host:' <<<"$former_legacy_failure"
grep -Fq 'lib/views/generic_database_page.dart' <<<"$former_legacy_failure"
rm "$fixture/lib/views/generic_database_page.dart"

cat > "$fixture/lib/views/new_legacy_page.dart" <<'EOF'
Future<void> newLegacyHost() async {
  try {
    throw StateError('new-private-value');
  } catch (error) {
    final message = 'New legacy debt: $error';
    if (message.isEmpty) return;
  }
}
EOF

set +e
legacy_spread_failure="$(cd "$fixture" && bash "$script" 2>&1)"
legacy_spread_status=$?
set -e

if [[ "$legacy_spread_status" -ne 1 ]]; then
  echo "Expected new legacy raw-error host to exit 1, got $legacy_spread_status" >&2
  exit 1
fi
grep -Fq 'Caught exception interpolation spread into a new legacy presentation host:' <<<"$legacy_spread_failure"
grep -Fq 'lib/views/new_legacy_page.dart' <<<"$legacy_spread_failure"
rm "$fixture/lib/views/new_legacy_page.dart"

cat > "$fixture/lib/features/object/presentation/widgets/unsafe_simple.dart" <<'EOF'
Future<void> runUnsafe() async {
  try {
    throw StateError('secret-path');
  } catch (error) {
    if (DateTime.now().microsecondsSinceEpoch > 0) {
      final message = 'Could not save: $error';
      if (message.isEmpty) return;
    }
  }
}
EOF

set +e
simple_failure="$(cd "$fixture" && bash "$script" 2>&1)"
simple_status=$?
set -e

if [[ "$simple_status" -ne 1 ]]; then
  echo "Expected direct caught-error interpolation to exit 1, got $simple_status" >&2
  exit 1
fi
grep -Fq 'Caught exception interpolation detected under canonical feature presentation:' <<<"$simple_failure"
grep -Fq "unsafe_simple.dart" <<<"$simple_failure"
grep -Fq "caught variable 'error' is interpolated into a string" <<<"$simple_failure"
rm "$fixture/lib/features/object/presentation/widgets/unsafe_simple.dart"

cat > "$fixture/lib/features/object/presentation/widgets/unsafe_braced.dart" <<'EOF'
Future<void> runUnsafeBraced() async {
  try {
    throw FormatException('secret-value');
  } catch (exception, stackTrace) {
    final message = 'Could not decode: ${exception.runtimeType}';
    if (message.isEmpty || stackTrace.toString().isEmpty) return;
  }
}
EOF

set +e
braced_failure="$(cd "$fixture" && bash "$script" 2>&1)"
braced_status=$?
set -e

if [[ "$braced_status" -ne 1 ]]; then
  echo "Expected braced caught-error interpolation to exit 1, got $braced_status" >&2
  exit 1
fi
grep -Fq 'unsafe_braced.dart' <<<"$braced_failure"
grep -Fq "caught variable 'exception' is interpolated into a string" <<<"$braced_failure"
rm "$fixture/lib/features/object/presentation/widgets/unsafe_braced.dart"

cat > "$fixture/lib/features/object/presentation/widgets/unsafe_even_escape.dart" <<'EOF'
Future<void> runUnsafeEvenEscape() async {
  try {
    throw StateError('secret-path');
  } catch (error) {
    final message = 'Backslash then raw error: \\$error';
    if (message.isEmpty) return;
  }
}
EOF

set +e
even_escape_failure="$(cd "$fixture" && bash "$script" 2>&1)"
even_escape_status=$?
set -e

if [[ "$even_escape_status" -ne 1 ]]; then
  echo "Expected interpolation after an escaped backslash to exit 1, got $even_escape_status" >&2
  exit 1
fi
grep -Fq 'unsafe_even_escape.dart' <<<"$even_escape_failure"

echo "feature_presentation_error_privacy_guard_test: PASS"
