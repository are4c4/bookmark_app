import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies custom and identity-sensitive primitive targets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final policy = RelationTargetQuickCreatePolicy(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );

    final customId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Author',
    );
    final tag = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
      name: 'Tag',
      icon: '🏷️',
    );
    final weblink = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final image = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final file = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: FileObjectService.systemKey,
      name: 'File',
      icon: '📎',
    );

    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: customId,
      ),
      RelationTargetQuickCreateMode.genericObject,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: tag.id,
      ),
      RelationTargetQuickCreateMode.tag,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: weblink.id,
      ),
      RelationTargetQuickCreateMode.weblinkUrl,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: image.id,
      ),
      RelationTargetQuickCreateMode.managedImage,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: file.id,
      ),
      RelationTargetQuickCreateMode.managedFile,
    );
  });

  test('unknown system, missing, and cross-workspace targets are unavailable',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final workspaceId = await workspaces.initialize();
    final otherWorkspaceId = await workspaces.createWorkspace('Other');
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final policy = RelationTargetQuickCreatePolicy(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );

    final internal = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'internal-test',
      name: 'Internal',
      icon: '⚙️',
    );
    final otherCustomId = await objectStore.createObjectType(
      workspaceId: otherWorkspaceId,
      name: 'Other',
    );

    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: internal.id,
      ),
      RelationTargetQuickCreateMode.unavailable,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: otherCustomId,
      ),
      RelationTargetQuickCreateMode.unavailable,
    );
    expect(
      await policy.modeFor(
        workspaceId: workspaceId,
        targetObjectTypeId: 999999,
      ),
      RelationTargetQuickCreateMode.unavailable,
    );
  });
}
