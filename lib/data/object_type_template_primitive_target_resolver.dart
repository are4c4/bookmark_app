import '../domain/object_model.dart';
import 'file_object_service.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';
import 'tag_object_bridge.dart';
import 'weblink_object_service.dart';

/// Resolves template Relation targets by stable system key without reimplementing
/// primitive schema semantics in the Database/View lane.
///
/// Existing system ObjectTypes are reused as-is. When one of the canonical
/// primitive targets has not been materialized in a fresh workspace yet, this
/// resolver delegates to that primitive's existing canonical ensure path.
/// Unknown system keys remain fail-closed.
class ObjectTypeTemplatePrimitiveTargetResolver {
  ObjectTypeTemplatePrimitiveTargetResolver({
    required this.genericStore,
    required this.objectStore,
  });

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;

  late final SystemObjectStore _systemObjects = SystemObjectStore(
    database: genericStore.database,
    objectStore: objectStore,
  );
  late final ObjectTypeDefaultsStore _defaults =
      ObjectTypeDefaultsStore(genericStore);

  Future<AppObjectType?> resolveOrProvision({
    required int workspaceId,
    required String systemKey,
  }) async {
    final key = systemKey.trim();
    if (key.isEmpty) return null;

    final existing = await _systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: key,
    );
    if (existing != null) return existing;

    switch (key) {
      case TagObjectBridge.systemKey:
        return (await TagObjectBridge(
          database: genericStore.database,
          objectStore: objectStore,
          systemObjectStore: _systemObjects,
        ).ensureTagObjectType(workspaceId))
            .objectType;
      case WeblinkObjectService.systemKey:
        return (await WeblinkObjectService(
          systemObjects: _systemObjects,
          defaultsStore: _defaults,
        ).ensureDefinition(workspaceId))
            .objectType;
      case ImageObjectService.systemKey:
        return (await ImageObjectService(
          systemObjects: _systemObjects,
          defaultsStore: _defaults,
        ).ensureDefinition(workspaceId))
            .objectType;
      case FileObjectService.systemKey:
        return (await FileObjectService(
          systemObjects: _systemObjects,
          defaultsStore: _defaults,
        ).ensureDefinition(workspaceId))
            .objectType;
      default:
        return null;
    }
  }
}
