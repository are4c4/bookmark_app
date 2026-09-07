#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/tool/maintainability_report.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/bookmark-maintainability-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

help_output="$(bash "$script" --help)"
grep -Fq -- '--max-boundary-refs <N>' <<<"$help_output"
grep -Fq -- '--max-feature-presentation-db-imports <N>' <<<"$help_output"
grep -Fq -- '--max-legacy-shim-imports <N>' <<<"$help_output"
grep -Fq -- '--max-legacy-shims <N>' <<<"$help_output"
grep -Fq 'Current CI-owned ceilings live in .github/workflows/flutter_ci.yml.' <<<"$help_output"
if grep -Eq -- '--max-(boundary-refs|feature-presentation-db-imports|legacy-shim-imports|legacy-shims) [0-9]+' <<<"$help_output"; then
  echo "Threshold help examples must not duplicate CI-owned numeric ceilings" >&2
  exit 1
fi

mkdir -p \
  "$fixture/lib/views" \
  "$fixture/lib/widgets" \
  "$fixture/lib/features/object/presentation" \
  "$fixture/test"
cat > "$fixture/lib/views/example_page.dart" <<'EOF'
import '../widgets/database_view_tabs.dart';
import '../features/database/presentation/widgets/database_page_toolbar.dart';
final first = repository.workspaceStore.database;
final second = repository.workspaceStore.database;
EOF
cat > "$fixture/lib/widgets/example_widget.dart" <<'EOF'
import 'detail_property_row.dart';
final database = repository.workspaceStore.database;
EOF
cat > "$fixture/lib/features/object/presentation/example_feature.dart" <<'EOF'
import '../../../data/app_database.dart';
final featureDatabase = repository.workspaceStore.database;
EOF
cat > "$fixture/test/example_test.dart" <<'EOF'
import 'package:bookmark_app/widgets/database_create_tiles.dart';
import 'package:bookmark_app/features/database/presentation/widgets/resizable_detail_pane.dart';
void main() {}
EOF
cat > "$fixture/lib/widgets/database_view_tabs.dart" <<'EOF'
export '../features/database/presentation/widgets/database_view_tabs.dart';
EOF
cat > "$fixture/lib/widgets/extra_database_compat.dart" <<'EOF'
export '../features/database/presentation/widgets/resizable_detail_pane.dart';
EOF

output="$(
  cd "$fixture" &&
    bash "$script" \
      --top 1 \
      --max-boundary-refs 4 \
      --max-feature-presentation-db-imports 1 \
      --max-legacy-shim-imports 3 \
      --max-legacy-shims 2
)"
grep -Fq '4 workspaceStore.database reference(s) across 3 file(s)' <<<"$output"
grep -Fq 'lib/features/object/presentation/example_feature.dart' <<<"$output"
grep -Fq 'Boundary regression threshold: 4 reference(s) maximum' <<<"$output"
grep -Fq '1 direct AppDatabase import(s) across 1 file(s)' <<<"$output"
grep -Fq 'Feature presentation AppDatabase import regression threshold: 1 import(s) maximum' <<<"$output"
grep -Fq '3 legacy shim import(s) across 3 file(s)' <<<"$output"
grep -Fq 'Legacy shim import regression threshold: 3 import(s) maximum' <<<"$output"
grep -Fq '2 legacy shim file(s)' <<<"$output"
grep -Fq 'Legacy shim file regression threshold: 2 file(s) maximum' <<<"$output"

set +e
boundary_failure="$(
  cd "$fixture" &&
    bash "$script" \
      --max-boundary-refs 3 \
      --max-feature-presentation-db-imports 1 \
      --max-legacy-shim-imports 3 \
      --max-legacy-shims 2 \
      2>&1
)"
boundary_status=$?
set -e

if [[ "$boundary_status" -ne 1 ]]; then
  echo "Expected boundary threshold breach to exit 1, got $boundary_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 4 presentation database reach-through references exceed maximum 3.' <<<"$boundary_failure"

set +e
feature_database_failure="$(
  cd "$fixture" &&
    bash "$script" \
      --max-boundary-refs 4 \
      --max-feature-presentation-db-imports 0 \
      --max-legacy-shim-imports 3 \
      --max-legacy-shims 2 \
      2>&1
)"
feature_database_status=$?
set -e

if [[ "$feature_database_status" -ne 1 ]]; then
  echo "Expected feature presentation AppDatabase import breach to exit 1, got $feature_database_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 1 canonical feature presentation AppDatabase imports exceed maximum 0.' <<<"$feature_database_failure"

set +e
shim_import_failure="$(
  cd "$fixture" &&
    bash "$script" \
      --max-boundary-refs 4 \
      --max-feature-presentation-db-imports 1 \
      --max-legacy-shim-imports 2 \
      --max-legacy-shims 2 \
      2>&1
)"
shim_import_status=$?
set -e

if [[ "$shim_import_status" -ne 1 ]]; then
  echo "Expected legacy shim import threshold breach to exit 1, got $shim_import_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 3 legacy Database presentation shim imports exceed maximum 2.' <<<"$shim_import_failure"

set +e
shim_file_failure="$(
  cd "$fixture" &&
    bash "$script" \
      --max-boundary-refs 4 \
      --max-feature-presentation-db-imports 1 \
      --max-legacy-shim-imports 3 \
      --max-legacy-shims 1 \
      2>&1
)"
shim_file_status=$?
set -e

if [[ "$shim_file_status" -ne 1 ]]; then
  echo "Expected legacy shim file threshold breach to exit 1, got $shim_file_status" >&2
  exit 1
fi
grep -Fq 'Maintainability regression: 2 legacy Database presentation re-export shim files exceed maximum 1.' <<<"$shim_file_failure"

# Prove the ratcheted production target is representable: once legacy imports
# and re-export shim files are gone, both accepted ceilings can stay at zero.
cat > "$fixture/lib/views/example_page.dart" <<'EOF'
import '../features/database/presentation/widgets/database_view_tabs.dart';
import '../features/database/presentation/widgets/database_page_toolbar.dart';
final first = repository.workspaceStore.database;
final second = repository.workspaceStore.database;
EOF
cat > "$fixture/lib/widgets/example_widget.dart" <<'EOF'
import '../features/database/presentation/widgets/detail_property_row.dart';
final database = repository.workspaceStore.database;
EOF
cat > "$fixture/test/example_test.dart" <<'EOF'
import 'package:bookmark_app/features/database/presentation/widgets/database_create_tiles.dart';
import 'package:bookmark_app/features/database/presentation/widgets/resizable_detail_pane.dart';
void main() {}
EOF
rm "$fixture/lib/widgets/database_view_tabs.dart"
rm "$fixture/lib/widgets/extra_database_compat.dart"

zero_shim_output="$(
  cd "$fixture" &&
    bash "$script" \
      --max-boundary-refs 4 \
      --max-feature-presentation-db-imports 1 \
      --max-legacy-shim-imports 0 \
      --max-legacy-shims 0
)"
grep -Fq '0 legacy shim import(s) across 0 file(s)' <<<"$zero_shim_output"
grep -Fq 'Legacy shim import regression threshold: 0 import(s) maximum' <<<"$zero_shim_output"
grep -Fq '0 legacy shim file(s)' <<<"$zero_shim_output"
grep -Fq 'Legacy shim file regression threshold: 0 file(s) maximum' <<<"$zero_shim_output"

echo "maintainability_report_test: PASS"
