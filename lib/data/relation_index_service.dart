import 'object_store.dart';

/// Explicit bootstrap/repair entry point for the normalized Relation edge index.
///
/// Legacy Relation values may exist in `generic_values` before the edge index
/// has been built. Rebuilding is idempotent and keeps backlinks/graph traversal
/// consistent without changing the stored Property values.
class RelationIndexService {
  const RelationIndexService(this.objectStore);

  final ObjectStore objectStore;

  Future<void> rebuildObjectType(int objectTypeId) =>
      objectStore.rebuildRelationIndex(objectTypeId);

  Future<void> rebuildWorkspace(int workspaceId) async {
    final objectTypes = await objectStore.listObjectTypes(workspaceId);
    for (final objectType in objectTypes) {
      await objectStore.rebuildRelationIndex(objectType.id);
    }
  }
}
