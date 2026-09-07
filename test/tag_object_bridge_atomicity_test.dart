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
  test('legacy Tag sync rolls back Object projection when Parent Relation write fails',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );

    await database.customStatement("INSERT INTO tags(name) VALUES ('くだもの')");
    final parentId = (await database.customSelect(
      "SELECT id FROM tags WHERE name = 'くだもの'",
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      "INSERT INTO tags(name, parent_tag_id) VALUES ('りんご', ?)",
      [parentId],
    );
    final childId = (await database.customSelect(
      "SELECT id FROM tags WHERE name = 'りんご'",
    ).getSingle())
        .read<int>('id');

    await bridge.syncLegacyTags(workspaceId);

    final tagType = (await systemStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    ))!;
    final parentProperty = tagType.properties.firstWhere(
      (property) => property.name == 'Parent',
    );
    final parentObjectId = (await bridge.objectIdForLegacyTag(
      workspaceId,
      parentId,
    ))!;
    final childObjectId = (await bridge.objectIdForLegacyTag(
      workspaceId,
      childId,
    ))!;

    await database.customStatement(
      "UPDATE tags SET name = '青りんご', parent_tag_id = NULL WHERE id = ?",
      [childId],
    );
    await database.customStatement('''
      CREATE TRIGGER fail_tag_parent_projection
      BEFORE UPDATE OF value_json ON generic_values
      WHEN NEW.record_id = $childObjectId
       AND NEW.property_id = ${parentProperty.id}
      BEGIN
        SELECT RAISE(ABORT, 'forced tag parent projection failure');
      END
    ''');

    await expectLater(
      bridge.syncLegacyTags(workspaceId),
      throwsA(anything),
    );

    final objects = await objectStore.listObjects(tagType.id);
    final child = objects.singleWhere((object) => object.id == childObjectId);
    expect(
      child.title,
      'りんご',
      reason: 'rename before the failed Parent write must roll back too',
    );
    expect(
      ObjectRelationValue.fromJson(child.values[parentProperty.id]).objectIds,
      [parentObjectId],
      reason: 'the previous canonical Parent Relation must remain intact',
    );

    final edges = (await objectStore.outgoingRelations(childObjectId))
        .where((edge) => edge.propertyId == parentProperty.id)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, parentObjectId);
    expect(edges.single.position, 0);

    final legacyTag = await database.customSelect(
      'SELECT name, parent_tag_id FROM tags WHERE id = ?',
      variables: [],
    );
    // Legacy Tag data is the source of truth and was changed before sync started;
    // only the mirrored Object/Relation projection is rolled back by sync.
    final row = await database.customSelect(
      'SELECT name, parent_tag_id FROM tags WHERE id = $childId',
    ).getSingle();
    expect(row.read<String>('name'), '青りんご');
    expect(row.readNullable<int>('parent_tag_id'), isNull);
  });
}
