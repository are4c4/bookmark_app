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
    final groupRow = await database
        .customSelect("SELECT id FROM tag_groups WHERE name = '分類'")
        .getSingle();
    final groupId = groupRow.read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, group_id) VALUES ('数学', ?)",
      <Object>[groupId],
    );
    final tagRow = await database
        .customSelect("SELECT id FROM tags WHERE name = '数学'")
        .getSingle();
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

  test('legacy resync preserves canonical TagGroup state', () async {
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
      "INSERT INTO tag_groups(name, sort_order) VALUES ('Legacy A', 0), ('Legacy B', 1)",
    );
    final groups = await database
        .customSelect('SELECT id, name FROM tag_groups ORDER BY sort_order')
        .get();
    final firstGroupId = groups.first.read<int>('id');
    final secondGroupId = groups.last.read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, group_id) VALUES ('数学', ?)",
      <Object>[firstGroupId],
    );
    final tagId =
        (await database
                .customSelect("SELECT id FROM tags WHERE name = '数学'")
                .getSingle())
            .read<int>('id');

    await bridge.syncLegacyTags(workspaceId);
    final schema = await bridge.ensureTagObjectType(workspaceId);
    final tagObjectId = (await bridge.objectIdForLegacyTag(
      workspaceId,
      tagId,
    ))!;
    final firstGroupObjectId = (await bridge.objectIdForLegacyTagGroup(
      workspaceId,
      firstGroupId,
    ))!;
    final secondGroupObjectId = (await bridge.objectIdForLegacyTagGroup(
      workspaceId,
      secondGroupId,
    ))!;

    await objectStore.renameObject(firstGroupObjectId, 'Canonical A');
    await bridge.hierarchyIntegrity.setGroup(
      workspaceId: workspaceId,
      tagObjectId: tagObjectId,
      groupProperty: schema.groupProperty,
      tagGroupObjectId: secondGroupObjectId,
    );
    await bridge.syncLegacyTags(workspaceId);

    var tagObject = (await objectStore.listObjects(schema.objectType.id))
        .singleWhere((object) => object.id == tagObjectId);
    var groupRelation = ObjectRelationValue.fromJson(
      tagObject.values[schema.groupProperty.id],
    );
    expect(groupRelation.objectIds, <int>[secondGroupObjectId]);
    final groupObject = (await objectStore.listObjects(
      schema.tagGroupObjectType.id,
    )).singleWhere((object) => object.id == firstGroupObjectId);
    expect(groupObject.title, 'Canonical A');

    await bridge.hierarchyIntegrity.setGroup(
      workspaceId: workspaceId,
      tagObjectId: tagObjectId,
      groupProperty: schema.groupProperty,
      tagGroupObjectId: null,
    );
    await bridge.syncLegacyTags(workspaceId);

    tagObject = (await objectStore.listObjects(schema.objectType.id))
        .singleWhere((object) => object.id == tagObjectId);
    groupRelation = ObjectRelationValue.fromJson(
      tagObject.values[schema.groupProperty.id],
    );
    expect(groupRelation.objectIds, isEmpty);
  });

  test(
    'legacy resync preserves an explicitly cleared canonical Parent',
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

      await database.customStatement("INSERT INTO tags(name) VALUES ('root')");
      final rootId =
          (await database
                  .customSelect("SELECT id FROM tags WHERE name = 'root'")
                  .getSingle())
              .read<int>('id');
      await database.customStatement(
        "INSERT INTO tags(name, parent_tag_id) VALUES ('child', ?)",
        <Object>[rootId],
      );
      final childId =
          (await database
                  .customSelect("SELECT id FROM tags WHERE name = 'child'")
                  .getSingle())
              .read<int>('id');

      await bridge.syncLegacyTags(workspaceId);
      final schema = await bridge.ensureTagObjectType(workspaceId);
      final childObjectId = (await bridge.objectIdForLegacyTag(
        workspaceId,
        childId,
      ))!;

      await bridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: childObjectId,
        parentProperty: schema.parentProperty,
        parentTagObjectId: null,
      );
      await bridge.syncLegacyTags(workspaceId);

      final childObject = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((object) => object.id == childObjectId);
      final parentRelation = ObjectRelationValue.fromJson(
        childObject.values[schema.parentProperty.id],
      );
      expect(parentRelation.objectIds, isEmpty);
      final legacyChild = await database
          .customSelect('SELECT parent_tag_id FROM tags WHERE id = $childId')
          .getSingle();
      expect(legacyChild.read<int>('parent_tag_id'), rootId);
    },
  );

  test(
    'legacy TagGroup deletion cannot delete canonical TagGroup state',
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
      final groupId =
          (await database
                  .customSelect("SELECT id FROM tag_groups WHERE name = '分類'")
                  .getSingle())
              .read<int>('id');
      await database.customStatement(
        "INSERT INTO tags(name, group_id) VALUES ('数学', ?)",
        <Object>[groupId],
      );
      final tagId =
          (await database
                  .customSelect("SELECT id FROM tags WHERE name = '数学'")
                  .getSingle())
              .read<int>('id');

      await bridge.syncLegacyTags(workspaceId);
      final schema = await bridge.ensureTagObjectType(workspaceId);
      final tagObjectId = (await bridge.objectIdForLegacyTag(
        workspaceId,
        tagId,
      ))!;
      final groupObjectId = (await bridge.objectIdForLegacyTagGroup(
        workspaceId,
        groupId,
      ))!;

      await database.customStatement(
        'DELETE FROM tag_groups WHERE id = ?',
        <Object>[groupId],
      );
      await bridge.syncLegacyTags(workspaceId);

      final groupObjects = await objectStore.listObjects(
        schema.tagGroupObjectType.id,
      );
      expect(groupObjects.any((object) => object.id == groupObjectId), isTrue);
      final tagObject = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((object) => object.id == tagObjectId);
      final groupRelation = ObjectRelationValue.fromJson(
        tagObject.values[schema.groupProperty.id],
      );
      expect(groupRelation.objectIds, <int>[groupObjectId]);
      final backlinks = await objectStore.backlinks(groupObjectId);
      expect(
        backlinks.any(
          (edge) =>
              edge.propertyId == schema.groupProperty.id &&
              edge.sourceObjectId == tagObjectId,
        ),
        isTrue,
      );
    },
  );
}
