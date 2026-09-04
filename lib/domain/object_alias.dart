/// Object-level alternate name metadata.
///
/// Aliases never replace Object identity. Persisted Relations and Body
/// references continue to store the canonical Object id; alias text is only a
/// lookup/display aid.
class ObjectAliasEntry {
  const ObjectAliasEntry({
    required this.objectId,
    required this.alias,
    required this.normalizedAlias,
    required this.position,
  });

  final int objectId;
  final String alias;
  final String normalizedAlias;
  final int position;
}

/// Cleans an alias for display/storage while preserving user-facing case.
///
/// Matching semantics intentionally stay simple and deterministic for the
/// first alias slice: trim leading/trailing whitespace and collapse internal
/// whitespace runs to one ASCII space. Unicode canonical normalization is not
/// attempted here.
String cleanObjectAlias(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Matching key used to de-duplicate aliases within one Object.
///
/// Dart's lowercase conversion is applied after whitespace normalization.
/// Aliases are not globally unique, so the same normalized alias may belong to
/// multiple Objects and callers must preserve that ambiguity in search UIs.
String normalizeObjectAlias(String value) => cleanObjectAlias(value).toLowerCase();

/// Returns cleaned aliases in input order, dropping blank and duplicate
/// normalized values while preserving the first user-facing spelling.
List<String> canonicalizeObjectAliases(Iterable<String> aliases) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in aliases) {
    final cleaned = cleanObjectAlias(raw);
    if (cleaned.isEmpty) continue;
    final normalized = normalizeObjectAlias(cleaned);
    if (seen.add(normalized)) result.add(cleaned);
  }
  return result;
}
