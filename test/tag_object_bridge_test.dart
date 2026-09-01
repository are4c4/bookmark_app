import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy tag hierarchy is mirrored as Tag objects', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(database: database, objectStore: objectStore);
    final bridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );

    await database.customStatement("INSERT INTO tags(name) VALUES ('くだもの')");
    final parentRow = await database.customSelect(
      "SELECT id FROM tags WHERE name = 'くだもの'",
    ).getSingle();
    final parentId = parentRow.read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, parent_tag_id) VALUES ('りんご', ?)",
      [parentId],
    );
    final childRow = await database.customSelect(
      "SELECT id FROM tags WHERE name = 'りんご'",
    ).getSingle();
    final childId = childRow.read<int>('id');

    await bridge.syncLegacyTags(workspaceId);

    final tagType = await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    );
    expect(tagType, isNotNull);
    expect(tagType!.kind, ObjectTypeKind.system);

    final parentObjectId = await bridge.objectIdForLegacyTag(parentId);
    final childObjectId = await bridge.objectIdForLegacyTag(childId);
    final objects = await objectStore.listObjects(tagType.id);
    expect(objects.map((object) => object.title).toSet(), {'くだもの', 'りんご'});

    final parentProperty = tagType.properties.firstWhere((p) => p.name == 'Parent');
    final child = objects.firstWhere((object) => object.id == childObjectId);
    expect(
      ObjectRelationValue.fromJson(child.values[parentProperty.id]).singleOrNull,
      parentObjectId,
    );
  });

  test('system object types are scoped per workspace', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final first = await workspaces.initialize();
    final second = await workspaces.createWorkspace('Second');
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(database: database, objectStore: objectStore);

    final firstType = await systemStore.ensureSystemObjectType(
      workspaceId: first,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );
    final secondType = await systemStore.ensureSystemObjectType(
      workspaceId: second,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );

    expect(firstType.id, isNot(secondType.id));
    expect(firstType.workspaceId, first);
    expect(secondType.workspaceId, second);
  });
}
