#!/usr/bin/env bash
set -euo pipefail

# New feature-owned code must stay on canonical Object/Database/View/Relation
# boundaries rather than reintroducing Bookmark-era domain types or depending
# back on legacy presentation hosts. Existing code outside lib/features remains
# compatibility debt tracked by #225.

if [[ ! -d lib/features ]]; then
  echo "Run this script from the repository root (lib/features was not found)." >&2
  exit 2
fi

legacy_domain_pattern='(^|[^A-Za-z0-9_])(BookmarkItem|BookmarkRepository)([^A-Za-z0-9_]|$)'
legacy_domain_matches="$({ grep -RInE --include='*.dart' "$legacy_domain_pattern" lib/features || true; })"

if [[ -n "$legacy_domain_matches" ]]; then
  echo "Legacy Bookmark dependency detected under lib/features:" >&2
  echo "$legacy_domain_matches" >&2
  echo >&2
  echo "Feature-owned code must not introduce BookmarkItem or BookmarkRepository." >&2
  echo "Use canonical Object/Database/View/Relation boundaries, or keep an explicitly" >&2
  echo "required compatibility bridge outside feature-owned code and document its" >&2
  echo "retirement condition in Issue #225." >&2
  exit 1
fi

legacy_presentation_pattern="^[[:space:]]*(import|export)[[:space:]]+['\"](package:bookmark_app/(views|widgets)/|(\.\./)+(views|widgets)/)"
legacy_presentation_matches="$({ grep -RInE --include='*.dart' "$legacy_presentation_pattern" lib/features || true; })"

if [[ -n "$legacy_presentation_matches" ]]; then
  echo "Legacy presentation dependency detected under lib/features:" >&2
  echo "$legacy_presentation_matches" >&2
  echo >&2
  echo "Feature-owned code must not import or export lib/views or lib/widgets." >&2
  echo "Move reusable presentation to a canonical feature/shared boundary instead of" >&2
  echo "making feature code depend back on a legacy presentation host." >&2
  exit 1
fi

echo "feature_legacy_dependency_guard: PASS"
