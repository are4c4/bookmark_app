import '../domain/object_alias.dart';
import '../domain/object_duplicate_candidate.dart';
import 'object_alias_store.dart';
import 'object_store.dart';

/// Exact, read-only duplicate diagnostics for generic Object identity text.
///
/// This service deliberately has no mutation/reuse authority. Native canonical
/// keys (for example Weblink URL identity) remain owned by their native
/// lifecycle services; title/alias overlap here is only advisory context.
class ObjectDuplicateAdvisoryService {
  const ObjectDuplicateAdvisoryService({
    required this.objectStore,
    required this.aliasStore,
  });

  final ObjectStore objectStore;
  final ObjectAliasStore aliasStore;

  Future<List<ObjectDuplicateCandidate>> findCandidates({
    required int objectTypeId,
    required String title,
    Iterable<String> aliases = const <String>[],
    int? excludingObjectId,
  }) async {
    if (objectTypeId <= 0) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType id must be positive.',
      );
    }
    if (excludingObjectId != null && excludingObjectId <= 0) {
      throw ArgumentError.value(
        excludingObjectId,
        'excludingObjectId',
        'Excluded Object id must be positive.',
      );
    }

    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }

    final proposedTerms = _proposedIdentityTerms(
      title: title,
      aliases: aliases,
    );
    if (proposedTerms.isEmpty) return const <ObjectDuplicateCandidate>[];

    final candidates = <ObjectDuplicateCandidate>[];
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == excludingObjectId) continue;

      final existingTerms = <_IdentityTerm>[
        if (normalizeObjectAlias(object.title).isNotEmpty)
          _IdentityTerm(
            kind: ObjectDuplicateIdentityKind.canonicalTitle,
            value: cleanObjectAlias(object.title),
          ),
        for (final alias in await aliasStore.listAliases(object.id))
          _IdentityTerm(kind: ObjectDuplicateIdentityKind.alias, value: alias),
      ];
      final matches = <ObjectDuplicateIdentityMatch>[];
      final seenMatches = <String>{};
      for (final proposed in proposedTerms) {
        for (final existing in existingTerms) {
          if (proposed.normalized != existing.normalized) continue;
          final key =
              '${proposed.kind.name}:${proposed.normalized}:'
              '${existing.kind.name}:${existing.normalized}';
          if (!seenMatches.add(key)) continue;
          matches.add(
            ObjectDuplicateIdentityMatch(
              proposedKind: proposed.kind,
              proposedValue: proposed.value,
              existingKind: existing.kind,
              existingValue: existing.value,
            ),
          );
        }
      }
      if (matches.isEmpty) continue;
      matches.sort(_compareMatches);
      candidates.add(
        ObjectDuplicateCandidate(
          objectId: object.id,
          objectTypeId: object.objectTypeId,
          canonicalTitle: object.title,
          matches: matches,
        ),
      );
    }

    candidates.sort((a, b) {
      final titleOrder = normalizeObjectAlias(a.canonicalTitle)
          .compareTo(normalizeObjectAlias(b.canonicalTitle));
      if (titleOrder != 0) return titleOrder;
      return a.objectId.compareTo(b.objectId);
    });
    return candidates;
  }
}

List<_IdentityTerm> _proposedIdentityTerms({
  required String title,
  required Iterable<String> aliases,
}) {
  final terms = <_IdentityTerm>[];
  final normalizedTitle = normalizeObjectAlias(title);
  if (normalizedTitle.isNotEmpty) {
    terms.add(
      _IdentityTerm(
        kind: ObjectDuplicateIdentityKind.canonicalTitle,
        value: cleanObjectAlias(title),
      ),
    );
  }
  for (final alias in canonicalizeObjectAliases(aliases)) {
    if (normalizeObjectAlias(alias) == normalizedTitle) continue;
    terms.add(
      _IdentityTerm(kind: ObjectDuplicateIdentityKind.alias, value: alias),
    );
  }
  return terms;
}

int _compareMatches(
  ObjectDuplicateIdentityMatch a,
  ObjectDuplicateIdentityMatch b,
) {
  final proposedKindOrder = a.proposedKind.index.compareTo(
    b.proposedKind.index,
  );
  if (proposedKindOrder != 0) return proposedKindOrder;
  final proposedValueOrder = normalizeObjectAlias(a.proposedValue)
      .compareTo(normalizeObjectAlias(b.proposedValue));
  if (proposedValueOrder != 0) return proposedValueOrder;
  final existingKindOrder = a.existingKind.index.compareTo(
    b.existingKind.index,
  );
  if (existingKindOrder != 0) return existingKindOrder;
  return normalizeObjectAlias(a.existingValue)
      .compareTo(normalizeObjectAlias(b.existingValue));
}

class _IdentityTerm {
  _IdentityTerm({required this.kind, required this.value})
    : normalized = normalizeObjectAlias(value);

  final ObjectDuplicateIdentityKind kind;
  final String value;
  final String normalized;
}
