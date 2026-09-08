#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

echo '==> Dart format (changed files)'
bash tool/check_format.sh

echo '==> Maintainability guard tests'
bash tool/maintainability_report_test.sh
bash tool/feature_legacy_dependency_guard_test.sh
bash tool/feature_presentation_error_privacy_guard_test.sh

echo '==> Maintainability regression ceilings'
bash tool/maintainability_report.sh \
  --max-boundary-refs 8 \
  --max-feature-presentation-db-imports 4 \
  --max-legacy-shim-imports 0 \
  --max-legacy-shims 0

echo '==> Feature legacy dependency guard'
bash tool/feature_legacy_dependency_guard.sh

echo '==> Feature presentation error privacy guard'
bash tool/feature_presentation_error_privacy_guard.sh

echo 'check_fast: passed'
