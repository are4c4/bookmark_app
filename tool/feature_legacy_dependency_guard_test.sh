#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/feature_legacy_dependency_guard.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-feature-legacy-guard-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/lib/features/object/presentation/widgets"
cat > "$fixture/lib/features/object/presentation/widgets/example.dart" <<'EOF'
import '../../../database/presentation/widgets/database_property_value_view.dart';

class ExampleObjectFeature {
  const ExampleObjectFeature();
}
EOF

output="$(cd "$fixture" && bash "$script")"
grep -Fq 'feature_legacy_dependency_guard: PASS' <<<"$output"

cat > "$fixture/lib/features/object/presentation/legacy_domain.dart" <<'EOF'
void useLegacy(BookmarkRepository repository, BookmarkItem bookmark) {}
EOF

set +e
domain_failure="$(cd "$fixture" && bash "$script" 2>&1)"
domain_status=$?
set -e

if [[ "$domain_status" -ne 1 ]]; then
  echo "Expected legacy feature domain dependency to exit 1, got $domain_status" >&2
  exit 1
fi
grep -Fq 'Legacy Bookmark dependency detected under lib/features:' <<<"$domain_failure"
grep -Fq 'BookmarkRepository' <<<"$domain_failure"
grep -Fq 'BookmarkItem' <<<"$domain_failure"
rm "$fixture/lib/features/object/presentation/legacy_domain.dart"

cat > "$fixture/lib/features/object/presentation/package_legacy.dart" <<'EOF'
import 'package:bookmark_app/widgets/app_toast.dart';
EOF

set +e
package_failure="$(cd "$fixture" && bash "$script" 2>&1)"
package_status=$?
set -e

if [[ "$package_status" -ne 1 ]]; then
  echo "Expected legacy package presentation dependency to exit 1, got $package_status" >&2
  exit 1
fi
grep -Fq 'Legacy presentation dependency detected under lib/features:' <<<"$package_failure"
grep -Fq 'package:bookmark_app/widgets/app_toast.dart' <<<"$package_failure"
rm "$fixture/lib/features/object/presentation/package_legacy.dart"

cat > "$fixture/lib/features/object/presentation/widgets/relative_legacy.dart" <<'EOF'
export '../../../../widgets/app_empty_state.dart';
EOF

set +e
relative_failure="$(cd "$fixture" && bash "$script" 2>&1)"
relative_status=$?
set -e

if [[ "$relative_status" -ne 1 ]]; then
  echo "Expected legacy relative presentation dependency to exit 1, got $relative_status" >&2
  exit 1
fi
grep -Fq 'Legacy presentation dependency detected under lib/features:' <<<"$relative_failure"
grep -Fq '../../../../widgets/app_empty_state.dart' <<<"$relative_failure"

echo "feature_legacy_dependency_guard_test: PASS"
