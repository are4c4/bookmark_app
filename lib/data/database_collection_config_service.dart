import '../domain/database_collection_definition.dart';
import '../domain/object_model.dart';
import '../domain/object_query.dart';
import 'database_collection_store.dart';
import 'object_store.dart';

class DatabaseCollectionConfigContext {
  const DatabaseCollectionConfigContext({
    required this.definition,
    required this.targetObjectType,
    required this.availableObjectTypes,
  });

  final DatabaseCollectionDefinition definition;
  final AppObjectType targetObjectType;
  final List<AppObjectType> availableObjectTypes;
}

/// Object-owned facade for editing Database collection semantics.
///
/// UI callers do not need to coordinate workspace validation, legacy fallback,
/// or target ObjectType lookup themselves. View configuration deliberately does
/// not appear here: Database membership and View presentation remain separate.
class DatabaseCollectionConfigService {
  const DatabaseCollectionConfigService({
    required this.collectionStore,
    required this.objectStore,
  });

  final DatabaseCollectionStore collectionStore;
  final ObjectStore objectStore;

  Future<DatabaseCollectionConfigContext?> load(int databaseId) async {
    final definition = await collectionStore.readEffective(databaseId);
    if (definition == null) return null;

    final target = await objectStore.getObjectType(definition.targetObjectTypeId);
    if (target == null) {
      throw StateError('Database collection target ObjectType is missing.');
    }

    final available = await objectStore.listObjectTypes(definition.workspaceId);
    return DatabaseCollectionConfigContext(
      definition: definition,
      targetObjectType: target,
      availableObjectTypes: List<AppObjectType>.unmodifiable(available),
    );
  }

  Future<void> save({
    required int databaseId,
    required int workspaceId,
    required int targetObjectTypeId,
    List<ObjectFilterRule> collectionFilter = const <ObjectFilterRule>[],
  }) {
    return collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetObjectTypeId,
        collectionFilter: collectionFilter,
      ),
    );
  }

  Future<void> resetToLegacy(int databaseId) => collectionStore.clear(databaseId);
}
