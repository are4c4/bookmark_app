import '../domain/object_alias.dart';
import '../domain/object_identity_search.dart';
import 'object_alias_store.dart';
import 'object_store.dart';

/// Searches Object identity by canonical title or Object-level aliases.
///
/// Results always carry canonical Object ids/titles. Alias text is presentation
/// context only; callers must persist [ObjectIdentitySearchResult.objectId].
class ObjectIdentitySearchService {
  const ObjectIdentitySearchService({
    required this.objectStore,
    required this.aliasStore,
  });

  final ObjectStore objectStore;
  final ObjectAliasStore aliasStore;

  Future<List<ObjectIdentitySearchResult>> search({
    required int workspaceId,
    required String query,
    int? objectTypeId,
  }) async {
    final normalizedQuery = normalizeObjectAlias(query);
    final types = await objectStore.listObjectTypes(workspaceId);
    final scopedTypes = objectTypeId == null
        ? types
        : types.where((type) => type.id == objectTypeId).toList(growable: false);
    if (objectTypeId != null && scopedTypes.isEmpty) {
      return const <ObjectIdentitySearchResult>[];
    }

    final results = <ObjectIdentitySearchResult>[];
    for (final type in scopedTypes) {
      final objects = await objectStore.listObjects(type.id);
      for (final object in objects) {
        final aliases = await aliasStore.listAliases(object.id);
        if (normalizedQuery.isEmpty) {
          results.add(
            ObjectIdentitySearchResult(
              object: object,
              objectType: type,
              aliases: aliases,
            ),
          );
          continue;
        }

        final normalizedTitle = normalizeObjectAlias(object.title);
        String? exactAlias;
        String? partialAlias;
        for (final alias in aliases) {
          final normalizedAlias = normalizeObjectAlias(alias);
          if (normalizedAlias == normalizedQuery) {
            exactAlias ??= alias;
          } else if (partialAlias == null &&
              normalizedAlias.contains(normalizedQuery)) {
            partialAlias = alias;
          }
        }

        String? matchedAlias;
        final matches = switch ((normalizedTitle, exactAlias, partialAlias)) {
          (final title, _, _) when title == normalizedQuery => true,
          (_, final alias?, _) => true,
          (final title, _, _) when title.contains(normalizedQuery) => true,
          (_, _, final alias?) => true,
          _ => false,
        };
        if (!matches) continue;

        if (normalizedTitle != normalizedQuery) {
          if (exactAlias != null) {
            matchedAlias = exactAlias;
          } else if (!normalizedTitle.contains(normalizedQuery)) {
            matchedAlias = partialAlias;
          }
        }

        results.add(
          ObjectIdentitySearchResult(
            object: object,
            objectType: type,
            aliases: aliases,
            matchedAlias: matchedAlias,
          ),
        );
      }
    }

    results.sort((a, b) {
      final aExactTitle = normalizeObjectAlias(a.canonicalTitle) == normalizedQuery;
      final bExactTitle = normalizeObjectAlias(b.canonicalTitle) == normalizedQuery;
      if (aExactTitle != bExactTitle) return aExactTitle ? -1 : 1;

      final aExactAlias = a.matchedAlias != null &&
          normalizeObjectAlias(a.matchedAlias!) == normalizedQuery;
      final bExactAlias = b.matchedAlias != null &&
          normalizeObjectAlias(b.matchedAlias!) == normalizedQuery;
      if (aExactAlias != bExactAlias) return aExactAlias ? -1 : 1;

      final typeOrder = a.objectType.name.compareTo(b.objectType.name);
      if (typeOrder != 0) return typeOrder;
      final titleOrder = a.canonicalTitle.compareTo(b.canonicalTitle);
      if (titleOrder != 0) return titleOrder;
      return a.objectId.compareTo(b.objectId);
    });
    return results;
  }
}
