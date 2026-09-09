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
  test('legacy TagGroup membership projects to canonical TagGroup Relation',
      () async {
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
    final groupId = (await database.customSelect(
      "SELECT id FROM tag_groups WHERE name = '分類'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, group_id) VALUES ('数学', ?)",
      <Object>[groupId],
    );
    final tagId = (await database.customSelect(
      "SELECT id FROM tags WHERE name = '数学'",
    ).getSingle())
        .read<int>('id');

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

    final tagObject = (await objectStore.listObjects(schema.objectType.id))
        .singleWhere((object) => object.id == resolvedTagObjectId);
    expect(
      ObjectRelationValue.fromJson(
        tagObject.values[schema.groupProperty.id],
      ).objectIds,
      <int>[resolvedGroupObjectId],
    );

    final groupObject = (await objectStore.listObjects(
      schema.tagGroupObjectType.id,
    ))
        .singleWhere((object) => object.id == resolvedGroupObjectId);
    expect(groupObject.title, '分類');
    expect(groupObject.values[schema.legacyTagGroupIdProperty.id], groupId);

    final backlinks = await objectStore.backlinks(resolvedGroupObjectId);
    final groupBacklinks = backlinks
        .where((edge) => edge.propertyId == schema.groupProperty.id)
        .toList(growable: false);
    expect(groupBacklinks, hasLength(1));
    expect(groupBacklinks.single.sourceObjectId, resolvedTagObjectId);
  });
}
