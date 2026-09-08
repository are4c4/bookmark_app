#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

echo '==> Fast checks'
bash tool/check_fast.sh

echo '==> Install dependencies'
flutter pub get

echo '==> Generate Drift code'
dart run build_runner build --delete-conflicting-outputs

echo '==> Analyze'
flutter analyze

echo '==> Full Flutter Test'
flutter test --timeout 2m

echo 'check_full: passed'
