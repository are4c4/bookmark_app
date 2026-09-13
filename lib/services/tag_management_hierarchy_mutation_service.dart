import '../data/bookmark_repository.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../data/tag_hierarchy_compatibility_mutation_service.dart';
import '../data/tag_object_bridge.dart';

/// Presentation-layer composition for the surviving Tag management tree.
///
/// The actual hierarchy mutation/integrity authority remains B's
/// [TagHierarchyCompatibilityMutationService]. This adapter only binds that
/// boundary to the current workspace so the legacy management surface cannot
/// accidentally fall back to legacy-first `TagGroupStore.moveTag` writes.
class TagManagementHierarchyMutationService {
  TagManagementHierarchyMutationService._({
    required int workspaceId,
    required TagHierarchyCompatibilityMutationService mutations,
  }) : _workspaceId = workspaceId,
       _mutations = mutations;

  factory TagManagementHierarchyMutationService.forRepository(
    BookmarkRepository repository,
  ) {
    final database = repository.lifecycleStore.database;
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    return TagManagementHierarchyMutationService._(
      workspaceId: repository.workspaceId,
      mutations: TagHierarchyCompatibilityMutationService(
        database: database,
        objectStore: objectStore,
        bridge: bridge,
      ),
    );
  }

  final int _workspaceId;
  final TagHierarchyCompatibilityMutationService _mutations;

  Future<TagCompatibilityMoveSnapshot> moveTag({
    required int tagId,
    int? parentTagId,
    int? groupId,
  }) => _mutations.moveTag(
    workspaceId: _workspaceId,
    tagId: tagId,
    parentTagId: parentTagId,
    groupId: groupId,
  );

  Future<void> restoreMove(TagCompatibilityMoveSnapshot snapshot) =>
      _mutations.restoreMove(workspaceId: _workspaceId, snapshot: snapshot);
}
