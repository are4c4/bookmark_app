import '../data/object_store.dart';
import '../domain/object_model.dart';
import 'object_search_repository.dart';

class ResolvedObjectSearchHit {
  const ResolvedObjectSearchHit({
    required this.hit,
    required this.object,
    required this.objectType,
  });

  final ObjectSearchHit hit;
  final AppObject object;
  final AppObjectType objectType;
}

/// Resolves canonical Object search ids into current Object/ObjectType data for
/// presentation and shared opening behavior.
///
/// Stale or inconsistent hits fail closed: deleted Objects, missing ObjectTypes,
/// and workspace/ObjectType mismatches are omitted instead of being opened as a
/// different entity. Result ranking/order from FTS is preserved.
class ObjectSearchResultResolver {
  const ObjectSearchResultResolver(this.objectStore);

  final ObjectStore objectStore;

  Future<List<ResolvedObjectSearchHit>> resolve(
    Iterable<ObjectSearchHit> hits,
  ) async {
    final orderedHits = hits.toList(growable: false);
    if (orderedHits.isEmpty) return const <ResolvedObjectSearchHit>[];

    final typeIds = orderedHits.map((hit) => hit.objectTypeId).toSet().toList()
      ..sort();
    final typesById = <int, AppObjectType>{};
    final objectsById = <int, AppObject>{};
    for (final typeId in typeIds) {
      final objectType = await objectStore.getObjectType(typeId);
      if (objectType == null) continue;
      typesById[typeId] = objectType;
      for (final object in await objectStore.listObjects(typeId)) {
        objectsById[object.id] = object;
      }
    }

    final resolved = <ResolvedObjectSearchHit>[];
    for (final hit in orderedHits) {
      final objectType = typesById[hit.objectTypeId];
      final object = objectsById[hit.objectId];
      if (objectType == null || object == null) continue;
      if (objectType.workspaceId != hit.workspaceId ||
          object.objectTypeId != hit.objectTypeId) {
        continue;
      }
      resolved.add(
        ResolvedObjectSearchHit(
          hit: hit,
          object: object,
          objectType: objectType,
        ),
      );
    }
    return List<ResolvedObjectSearchHit>.unmodifiable(resolved);
  }
}
