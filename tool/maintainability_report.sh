#!/usr/bin/env bash
set -euo pipefail

# Reports Dart LOC without changing the repository. This is intentionally a
# visibility tool first: existing hotspots are debt to reduce, not CI failures.
#
# Usage:
#   bash tool/maintainability_report.sh
#   bash tool/maintainability_report.sh --top 30

TOP=20

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
    -h|--help)
      sed -n '3,10p' "$0"
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
trap 'rm -f "$tmp_file"' EXIT

scan_root() {
  local root="$1"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.dart' -print | while IFS= read -r file; do
    lines="$(wc -l < "$file" | tr -d ' ')"
    printf '%08d\t%s\n' "$lines" "$file"
  done
}

{
  scan_root lib
  scan_root test
} | sort -r > "$tmp_file"

lib_files="$(awk -F '\t' '$2 ~ /^lib\// { count++ } END { print count + 0 }' "$tmp_file")"
lib_loc="$(awk -F '\t' '$2 ~ /^lib\// { sum += $1 } END { print sum + 0 }' "$tmp_file")"
test_files="$(awk -F '\t' '$2 ~ /^test\// { count++ } END { print count + 0 }' "$tmp_file")"
test_loc="$(awk -F '\t' '$2 ~ /^test\// { sum += $1 } END { print sum + 0 }' "$tmp_file")"

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
echo "Policy: this report is non-blocking. Existing hotspots must not be hidden by"
echo "moving code without reducing responsibility or duplication. Review major LOC"
echo "growth against docs/MAINTAINABILITY.md and Issue #225."
