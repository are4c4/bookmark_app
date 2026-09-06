#!/usr/bin/env bash
set -euo pipefail

# Reports Dart LOC and selected dependency-boundary debt without changing the
# repository. Existing hotspots stay non-blocking by default; callers may opt
# into regression-only thresholds for presentation/database reach-through and
# legacy Database-presentation re-export imports.
#
# Usage:
#   bash tool/maintainability_report.sh
#   bash tool/maintainability_report.sh --top 30
#   bash tool/maintainability_report.sh --max-boundary-refs 12
#   bash tool/maintainability_report.sh --max-legacy-shim-imports 22

TOP=20
MAX_BOUNDARY_REFS=""
MAX_LEGACY_SHIM_IMPORTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --top)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -eq 0 ]]; then
        echo "--top requires a positive integer" >&2
        exit 2
      fi
      TOP="$2"
      shift 2
      ;;
    --max-boundary-refs)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "--max-boundary-refs requires a non-negative integer" >&2
        exit 2
      fi
      MAX_BOUNDARY_REFS="$2"
      shift 2
      ;;
    --max-legacy-shim-imports)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "--max-legacy-shim-imports requires a non-negative integer" >&2
        exit 2
      fi
      MAX_LEGACY_SHIM_IMPORTS="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '3,13p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d lib ]]; then
  echo "Run this script from the repository root (lib/ was not found)." >&2
  exit 2
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/bookmark-maintainability.XXXXXX")"
boundary_file="$(mktemp "${TMPDIR:-/tmp}/bookmark-boundaries.XXXXXX")"
legacy_shim_file="$(mktemp "${TMPDIR:-/tmp}/bookmark-legacy-shims.XXXXXX")"
trap 'rm -f "$tmp_file" "$boundary_file" "$legacy_shim_file"' EXIT

scan_root() {
  local root="$1"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.dart' -print | while IFS= read -r file; do
    lines="$(wc -l < "$file" | tr -d ' ')"
    printf '%08d\t%s\n' "$lines" "$file"
  done
}

scan_presentation_database_reachthrough() {
  for root in lib/views lib/widgets; do
    [[ -d "$root" ]] || continue
    find "$root" -type f -name '*.dart' -print | while IFS= read -r file; do
      count="$(
        { grep -o 'workspaceStore\.database' "$file" 2>/dev/null || true; } |
          wc -l |
          tr -d ' '
      )"
      if [[ "$count" -gt 0 ]]; then
        printf '%08d\t%s\n' "$count" "$file"
      fi
    done
  done
}

scan_legacy_presentation_shim_imports() {
  local shim_names='database_page_toolbar|database_view_tabs|database_create_tiles|resizable_detail_pane|detail_property_row'
  local import_pattern="^[[:space:]]*import[[:space:]]+['\"]((package:bookmark_app/widgets/|(\.\./)+widgets/)?)((${shim_names}))\\.dart['\"]"

  for root in lib test; do
    [[ -d "$root" ]] || continue
    find "$root" -type f -name '*.dart' -print | while IFS= read -r file; do
      count="$(
        { grep -E "$import_pattern" "$file" 2>/dev/null || true; } |
          wc -l |
          tr -d ' '
      )"
      if [[ "$count" -gt 0 ]]; then
        printf '%08d\t%s\n' "$count" "$file"
      fi
    done
  done
}

{
  scan_root lib
  scan_root test
} | sort -r > "$tmp_file"

scan_presentation_database_reachthrough | sort -r > "$boundary_file"
scan_legacy_presentation_shim_imports | sort -r > "$legacy_shim_file"

lib_files="$(awk -F '\t' '$2 ~ /^lib\// { count++ } END { print count + 0 }' "$tmp_file")"
lib_loc="$(awk -F '\t' '$2 ~ /^lib\// { sum += $1 } END { print sum + 0 }' "$tmp_file")"
test_files="$(awk -F '\t' '$2 ~ /^test\// { count++ } END { print count + 0 }' "$tmp_file")"
test_loc="$(awk -F '\t' '$2 ~ /^test\// { sum += $1 } END { print sum + 0 }' "$tmp_file")"
boundary_files="$(awk -F '\t' 'END { print NR + 0 }' "$boundary_file")"
boundary_refs="$(awk -F '\t' '{ sum += $1 } END { print sum + 0 }' "$boundary_file")"
legacy_shim_files="$(awk -F '\t' 'END { print NR + 0 }' "$legacy_shim_file")"
legacy_shim_imports="$(awk -F '\t' '{ sum += $1 } END { print sum + 0 }' "$legacy_shim_file")"

echo "Dart maintainability report"
echo "==========================="
printf 'lib/:  %s files, %s LOC\n' "$lib_files" "$lib_loc"
printf 'test/: %s files, %s LOC\n' "$test_files" "$test_loc"
echo
echo "Largest Dart files (top $TOP):"
printf '%8s  %s\n' 'LOC' 'path'
printf '%8s  %s\n' '--------' '----'
head -n "$TOP" "$tmp_file" | while IFS=$'\t' read -r lines file; do
  # Strip zero padding used only to make lexical sort numeric.
  lines="${lines#0000000}"
  lines="${lines#000000}"
  lines="${lines#00000}"
  lines="${lines#0000}"
  lines="${lines#000}"
  lines="${lines#00}"
  lines="${lines#0}"
  [[ -n "$lines" ]] || lines=0
  printf '%8s  %s\n' "$lines" "$file"
done

echo
echo "Presentation direct database reach-through:"
printf '  %s workspaceStore.database reference(s) across %s file(s)\n' \
  "$boundary_refs" "$boundary_files"
if [[ "$boundary_files" -gt 0 ]]; then
  printf '%8s  %s\n' 'refs' 'path'
  printf '%8s  %s\n' '--------' '----'
  while IFS=$'\t' read -r refs file; do
    refs="${refs#0000000}"
    refs="${refs#000000}"
    refs="${refs#00000}"
    refs="${refs#0000}"
    refs="${refs#000}"
    refs="${refs#00}"
    refs="${refs#0}"
    [[ -n "$refs" ]] || refs=0
    printf '%8s  %s\n' "$refs" "$file"
  done < "$boundary_file"
fi

echo
echo "Legacy Database presentation re-export imports:"
printf '  %s legacy shim import(s) across %s file(s)\n' \
  "$legacy_shim_imports" "$legacy_shim_files"
if [[ "$legacy_shim_files" -gt 0 ]]; then
  printf '%8s  %s\n' 'imports' 'path'
  printf '%8s  %s\n' '--------' '----'
  while IFS=$'\t' read -r imports file; do
    imports="${imports#0000000}"
    imports="${imports#000000}"
    imports="${imports#00000}"
    imports="${imports#0000}"
    imports="${imports#000}"
    imports="${imports#00}"
    imports="${imports#0}"
    [[ -n "$imports" ]] || imports=0
    printf '%8s  %s\n' "$imports" "$file"
  done < "$legacy_shim_file"
fi

if [[ -n "$MAX_BOUNDARY_REFS" ]]; then
  echo
  echo "Boundary regression threshold: $MAX_BOUNDARY_REFS reference(s) maximum"
  if [[ "$boundary_refs" -gt "$MAX_BOUNDARY_REFS" ]]; then
    echo "Maintainability regression: $boundary_refs presentation database reach-through references exceed maximum $MAX_BOUNDARY_REFS." >&2
    exit 1
  fi
fi

if [[ -n "$MAX_LEGACY_SHIM_IMPORTS" ]]; then
  echo
  echo "Legacy shim import regression threshold: $MAX_LEGACY_SHIM_IMPORTS import(s) maximum"
  if [[ "$legacy_shim_imports" -gt "$MAX_LEGACY_SHIM_IMPORTS" ]]; then
    echo "Maintainability regression: $legacy_shim_imports legacy Database presentation shim imports exceed maximum $MAX_LEGACY_SHIM_IMPORTS." >&2
    exit 1
  fi
fi

echo
echo "Policy: this report is non-blocking unless an explicit regression threshold is supplied."
echo "Existing hotspots, boundary debt, and temporary shim imports must not be hidden by moving"
echo "code without reducing responsibility or duplication. Review major LOC/boundary growth"
echo "against docs/MAINTAINABILITY.md and Issue #225."