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
  test('creates root child grandchild hierarchy through canonical Relations',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final rootId = await fixture.createTag('くだもの');
    final childId = await fixture.createTag('りんご');
    final grandchildId = await fixture.createTag('青りんご');

    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: childId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: rootId,
    );
    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: grandchildId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: childId,
    );

    final objects = await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    );
    final root = objects.singleWhere((object) => object.id == rootId);
    final child = objects.singleWhere((object) => object.id == childId);
    final grandchild = objects.singleWhere((object) => object.id == grandchildId);

    expect(_parentId(root, fixture.schema.parentProperty), isNull);
    expect(_parentId(child, fixture.schema.parentProperty), rootId);
    expect(_parentId(grandchild, fixture.schema.parentProperty), childId);

    final rootBacklinks = await fixture.objectStore.backlinks(rootId);
    expect(
      rootBacklinks.where(
        (edge) => edge.propertyId == fixture.schema.parentProperty.id,
      ),
      hasLength(1),
    );
    expect(
      rootBacklinks.singleWhere(
        (edge) => edge.propertyId == fixture.schema.parentProperty.id,
      ).sourceObjectId,
      childId,
    );
  });

  test('rejects self and indirect cycles before mutating canonical state',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final rootId = await fixture.createTag('くだもの');
    final childId = await fixture.createTag('りんご');
    final grandchildId = await fixture.createTag('青りんご');
    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: childId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: rootId,
    );
    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: grandchildId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: childId,
    );

    await expectLater(
      fixture.bridge.hierarchyIntegrity.setParent(
        workspaceId: fixture.workspaceId,
        tagObjectId: rootId,
        parentProperty: fixture.schema.parentProperty,
        parentTagObjectId: rootId,
      ),
      throwsArgumentError,
    );
    await expectLater(
      fixture.bridge.hierarchyIntegrity.setParent(
        workspaceId: fixture.workspaceId,
        tagObjectId: rootId,
        parentProperty: fixture.schema.parentProperty,
        parentTagObjectId: grandchildId,
      ),
      throwsStateError,
    );

    final objects = await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    );
    expect(
      _parentId(
        objects.singleWhere((object) => object.id == rootId),
        fixture.schema.parentProperty,
      ),
      isNull,
    );
    expect(
      _parentId(
        objects.singleWhere((object) => object.id == childId),
        fixture.schema.parentProperty,
      ),
      rootId,
    );
    expect(
      _parentId(
        objects.singleWhere((object) => object.id == grandchildId),
        fixture.schema.parentProperty,
      ),
      childId,
    );
  });

  test('rejects wrong-type parent targets without partial mutation', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final tagId = await fixture.createTag('数学');
    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final wrongTargetId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Not a Tag',
    );

    await expectLater(
      fixture.bridge.hierarchyIntegrity.setParent(
        workspaceId: fixture.workspaceId,
        tagObjectId: tagId,
        parentProperty: fixture.schema.parentProperty,
        parentTagObjectId: wrongTargetId,
      ),
      throwsArgumentError,
    );

    final tag = (await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    ))
        .singleWhere((object) => object.id == tagId);
    expect(_parentId(tag, fixture.schema.parentProperty), isNull);
    expect(
      (await fixture.objectStore.outgoingRelations(tagId)).where(
        (edge) => edge.propertyId == fixture.schema.parentProperty.id,
      ),
      isEmpty,
    );
  });

  test('fails closed on Parent stored/index drift instead of repairing it',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final rootId = await fixture.createTag('くだもの');
    final childId = await fixture.createTag('りんご');
    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: childId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: rootId,
    );
    await fixture.database.customStatement(
      'UPDATE object_relation_edges SET position = 7 '
      'WHERE source_object_id = ? AND property_id = ?',
      <Object>[childId, fixture.schema.parentProperty.id],
    );

    await expectLater(
      fixture.bridge.hierarchyIntegrity.setParent(
        workspaceId: fixture.workspaceId,
        tagObjectId: childId,
        parentProperty: fixture.schema.parentProperty,
      ),
      throwsStateError,
    );

    final child = (await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    ))
        .singleWhere((object) => object.id == childId);
    expect(_parentId(child, fixture.schema.parentProperty), rootId);
    final edges = (await fixture.objectStore.outgoingRelations(childId))
        .where((edge) => edge.propertyId == fixture.schema.parentProperty.id)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, rootId);
    expect(edges.single.position, 7);
  });

  test('Tag Group membership accepts only canonical TagGroup Objects', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final tagId = await fixture.createTag('数学');
    final groupId = await fixture.objectStore.createObject(
      objectTypeId: fixture.schema.tagGroupObjectType.id,
      title: '分野',
    );
    await fixture.bridge.hierarchyIntegrity.setGroup(
      workspaceId: fixture.workspaceId,
      tagObjectId: tagId,
      groupProperty: fixture.schema.groupProperty,
      tagGroupObjectId: groupId,
    );

    final tag = (await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    ))
        .singleWhere((object) => object.id == tagId);
    expect(
      ObjectRelationValue.fromJson(
        tag.values[fixture.schema.groupProperty.id],
      ).objectIds,
      <int>[groupId],
    );

    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final wrongGroupId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Not a TagGroup',
    );
    await expectLater(
      fixture.bridge.hierarchyIntegrity.setGroup(
        workspaceId: fixture.workspaceId,
        tagObjectId: tagId,
        groupProperty: fixture.schema.groupProperty,
        tagGroupObjectId: wrongGroupId,
      ),
      throwsArgumentError,
    );

    final unchanged = (await fixture.objectStore.listObjects(
      fixture.schema.objectType.id,
    ))
        .singleWhere((object) => object.id == tagId);
    expect(
      ObjectRelationValue.fromJson(
        unchanged.values[fixture.schema.groupProperty.id],
      ).objectIds,
      <int>[groupId],
    );
  });

  test('direct Object Tag assignment does not persist derived ancestors',
      () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);

    final rootId = await fixture.createTag('くだもの');
    final childId = await fixture.createTag('りんご');
    await fixture.bridge.hierarchyIntegrity.setParent(
      workspaceId: fixture.workspaceId,
      tagObjectId: childId,
      parentProperty: fixture.schema.parentProperty,
      parentTagObjectId: rootId,
    );

    final noteTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Note',
    );
    final tagsPropertyId = await fixture.objectStore.createRelationProperty(
      objectTypeId: noteTypeId,
      name: 'Tags',
      targetObjectTypeId: fixture.schema.objectType.id,
      multiple: true,
    );
    final tagsProperty = (await fixture.objectStore.getObjectType(noteTypeId))!
        .properties
        .singleWhere((property) => property.id == tagsPropertyId);
    final noteId = await fixture.objectStore.createObject(
      objectTypeId: noteTypeId,
      title: 'Apple note',
    );
    await fixture.objectStore.setRelation(
      objectId: noteId,
      property: tagsProperty,
      targetObjectIds: <int>[childId],
    );

    final note = (await fixture.objectStore.listObjects(noteTypeId))
        .singleWhere((object) => object.id == noteId);
    expect(
      ObjectRelationValue.fromJson(note.values[tagsProperty.id]).objectIds,
      <int>[childId],
    );
    expect(
      ObjectRelationValue.fromJson(note.values[tagsProperty.id]).objectIds,
      isNot(contains(rootId)),
    );
  });
}

int? _parentId(AppObject object, ObjectPropertyDefinition parentProperty) {
  final ids = ObjectRelationValue.fromJson(
    object.values[parentProperty.id],
  ).objectIds;
  return ids.isEmpty ? null : ids.single;
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
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
  final schema = await bridge.ensureTagObjectType(workspaceId);
  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    objectStore: objectStore,
    bridge: bridge,
    schema: schema,
  );
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.objectStore,
    required this.bridge,
    required this.schema,
  });

  final AppDatabase database;
  final int workspaceId;
  final ObjectStore objectStore;
  final TagObjectBridge bridge;
  final TagObjectSchema schema;

  Future<int> createTag(String title) => objectStore.createObject(
        objectTypeId: schema.objectType.id,
        title: title,
      );
}
