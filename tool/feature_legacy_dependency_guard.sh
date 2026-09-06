#!/usr/bin/env bash
set -euo pipefail

# New feature-owned code must stay on canonical Object/Database/View/Relation
# boundaries rather than reintroducing Bookmark-era domain types. Existing
# legacy hosts outside lib/features remain compatibility debt tracked by #225.

if [[ ! -d lib/features ]]; then
  echo "Run this script from the repository root (lib/features was not found)." >&2
  exit 2
fi

legacy_pattern='(^|[^A-Za-z0-9_])(BookmarkItem|BookmarkRepository)([^A-Za-z0-9_]|$)'
matches="$({ grep -RInE --include='*.dart' "$legacy_pattern" lib/features || true; })"

if [[ -n "$matches" ]]; then
  echo "Legacy Bookmark dependency detected under lib/features:" >&2
  echo "$matches" >&2
  echo >&2
  echo "Feature-owned code must not introduce BookmarkItem or BookmarkRepository." >&2
  echo "Use canonical Object/Database/View/Relation boundaries, or keep an explicitly" >&2
  echo "required compatibility bridge outside feature-owned code and document its" >&2
  echo "retirement condition in Issue #225." >&2
  exit 1
fi

echo "feature_legacy_dependency_guard: PASS"
