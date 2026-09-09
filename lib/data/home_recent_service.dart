import '../domain/object_model.dart';
import 'core_object_bridge.dart';
import 'object_store.dart';
import 'system_object_store.dart';

class HomeRecentObject {
  const HomeRecentObject({required this.object, required this.objectType});

  final AppObject object;
  final AppObjectType objectType;
}

/// Builds the Home Recent section from canonical Object state.
///
/// Recent currently means "recently changed" and deliberately derives from the
/// existing Object `updatedAt` timestamp. Tracking "recently opened" is a
/// separate durable user-state contract and must not be faked as UI-only state.
class HomeRecentService {
  const HomeRecentService({
    required this.objectStore,
    required this.systemObjects,
  });

  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  Future<List<HomeRecentObject>> listRecentlyChanged({
    required int workspaceId,
    int limit = 12,
  }) async {
    if (limit <= 0) return const <HomeRecentObject>[];

    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    final result = <HomeRecentObject>[];
    for (final objectType in objectTypes) {
      final systemKey = await systemObjects.systemKeyForObjectType(
        objectType.id,
      );
      if (systemKey == CoreObjectBridge.bookmarkSystemKey) continue;

      final objects = await objectStore.listObjects(objectType.id);
      result.addAll(
        objects.map(
          (object) => HomeRecentObject(object: object, objectType: objectType),
        ),
      );
    }

    result.sort((left, right) {
      final updated = right.object.updatedAt.compareTo(left.object.updatedAt);
      if (updated != 0) return updated;
      return right.object.id.compareTo(left.object.id);
    });

    return List<HomeRecentObject>.unmodifiable(
      result.length <= limit ? result : result.take(limit),
    );
  }
}
