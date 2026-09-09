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
  test('legacy TagGroup projects as a canonical Relation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );

    await database.customStatement(
      "INSERT INTO tag_groups(name, sort_order) VALUES ('分類', 0)",
    );
    final groupRow = await database.customSelect(
      "SELECT id FROM tag_groups WHERE name = '分類'",
    ).getSingle();
    final groupId = groupRow.read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, group_id) VALUES ('数学', ?)",
      <Object>[groupId],
    );
    final tagRow = await database.customSelect(
      "SELECT id FROM tags WHERE name = '数学'",
    ).getSingle();
    final tagId = tagRow.read<int>('id');

    await bridge.syncLegacyTags(workspaceId);

    final schema = await bridge.ensureTagObjectType(workspaceId);
    final tagObjectId = await bridge.objectIdForLegacyTag(workspaceId, tagId);
    final groupObjectId = await bridge.objectIdForLegacyTagGroup(
      workspaceId,
      groupId,
    );
    expect(tagObjectId, isNotNull);
    expect(groupObjectId, isNotNull);
    final resolvedTagObjectId = tagObjectId!;
    final resolvedGroupObjectId = groupObjectId!;

    final tagObjects = await objectStore.listObjects(schema.objectType.id);
    final tagObject = tagObjects.singleWhere(
      (object) => object.id == resolvedTagObjectId,
    );
    final groupRelation = ObjectRelationValue.fromJson(
      tagObject.values[schema.groupProperty.id],
    );
    expect(groupRelation.objectIds, <int>[resolvedGroupObjectId]);

    final groupObjects = await objectStore.listObjects(
      schema.tagGroupObjectType.id,
    );
    final groupObject = groupObjects.singleWhere(
      (object) => object.id == resolvedGroupObjectId,
    );
    expect(groupObject.title, '分類');
    expect(groupObject.values[schema.legacyTagGroupIdProperty.id], groupId);

    final backlinks = await objectStore.backlinks(resolvedGroupObjectId);
    final groupBacklinks = backlinks.where(
      (edge) => edge.propertyId == schema.groupProperty.id,
    );
    expect(groupBacklinks, hasLength(1));
    expect(groupBacklinks.single.sourceObjectId, resolvedTagObjectId);
  });
}
