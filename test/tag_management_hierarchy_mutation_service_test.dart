import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/tag_management_hierarchy_mutation_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Tag management move and undo keep canonical hierarchy and compatibility state equivalent',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceStore = WorkspaceStore(database);
      final workspaceId = await workspaceStore.initialize();
      final lifecycleStore = BookmarkLifecycleStore(database);
      await lifecycleStore.initialize();
      addTearDown(lifecycleStore.dispose);
      final repository = BookmarkRepository(
        database,
        workspaceStore: workspaceStore,
        lifecycleStore: lifecycleStore,
        workspaceId: workspaceId,
      );
      final tagGroups = TagGroupStore(database);
      await tagGroups.initialize();
      final groupId = await tagGroups.createGroup('Group');
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
      final schema = await bridge.ensureTagObjectType(workspaceId);
      final parentId = await database.createTag('parent');
      final childId = await database.createTag('child');
      await bridge.syncLegacyTags(workspaceId);
      final parentObjectId = await bridge.objectIdForLegacyTag(
        workspaceId,
        parentId,
      );
      final childObjectId = await bridge.objectIdForLegacyTag(
        workspaceId,
        childId,
      );
      final groupObjectId = await bridge.objectIdForLegacyTagGroup(
        workspaceId,
        groupId,
      );
      expect(parentObjectId, isNotNull);
      expect(childObjectId, isNotNull);
      expect(groupObjectId, isNotNull);

      final service = TagManagementHierarchyMutationService.forRepository(
        repository,
      );
      final snapshot = await service.moveTag(
        tagId: childId,
        parentTagId: parentId,
        groupId: groupId,
      );

      final movedChild = (await repository.watchTags().first)
          .singleWhere((tag) => tag.id == childId);
      expect(movedChild.parentTagId, parentId);
      expect(movedChild.groupId, groupId);
      final movedHierarchy = await bridge.hierarchyIntegrity.loadSnapshot(
        workspaceId: workspaceId,
        parentProperty: schema.parentProperty,
      );
      expect(
        movedHierarchy.parentByTagObjectId[childObjectId!],
        parentObjectId,
      );
      final movedGroup = await bridge.hierarchyIntegrity.relationTargets
          .selectionForMutation(
            workspaceId: workspaceId,
            sourceObjectId: childObjectId,
            property: schema.groupProperty,
          );
      expect(movedGroup.selectedObjectIds, <int>[groupObjectId!]);

      await service.restoreMove(snapshot);

      final restoredChild = (await repository.watchTags().first)
          .singleWhere((tag) => tag.id == childId);
      expect(restoredChild.parentTagId, isNull);
      expect(restoredChild.groupId, isNull);
      final restoredHierarchy = await bridge.hierarchyIntegrity.loadSnapshot(
        workspaceId: workspaceId,
        parentProperty: schema.parentProperty,
      );
      expect(restoredHierarchy.parentByTagObjectId[childObjectId], isNull);
      final restoredGroup = await bridge.hierarchyIntegrity.relationTargets
          .selectionForMutation(
            workspaceId: workspaceId,
            sourceObjectId: childObjectId,
            property: schema.groupProperty,
          );
      expect(restoredGroup.selectedObjectIds, isEmpty);
    },
  );
}
