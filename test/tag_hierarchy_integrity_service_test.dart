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
  test('creates a canonical root child grandchild hierarchy', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final rootId = await fixture.createTag('くだもの');
    final childId = await fixture.createTag('りんご');
    final grandchildId = await fixture.createTag('青りんご');

    await fixture.setParent(childId, rootId);
    await fixture.setParent(grandchildId, childId);

    expect(await fixture.parentId(rootId), isNull);
    expect(await fixture.parentId(childId), rootId);
    expect(await fixture.parentId(grandchildId), childId);
    final backlinks = await fixture.objectStore.backlinks(rootId);
    final parentBacklinks = backlinks.where(
      (edge) => edge.propertyId == fixture.schema.parentProperty.id,
    );
    expect(parentBacklinks, hasLength(1));
    expect(parentBacklinks.single.sourceObjectId, childId);
  });

  test('rejects self and indirect Tag parent cycles before mutation', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final rootId = await fixture.createTag('root');
    final childId = await fixture.createTag('child');
    final grandchildId = await fixture.createTag('grandchild');
    await fixture.setParent(childId, rootId);
    await fixture.setParent(grandchildId, childId);

    await expectLater(fixture.setParent(rootId, rootId), throwsArgumentError);
    await expectLater(
      fixture.setParent(rootId, grandchildId),
      throwsStateError,
    );

    expect(await fixture.parentId(rootId), isNull);
    expect(await fixture.parentId(childId), rootId);
    expect(await fixture.parentId(grandchildId), childId);
  });

  test('rejects a wrong-type Tag parent target without mutation', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final tagId = await fixture.createTag('数学');
    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final wrongTargetId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Wrong',
    );

    await expectLater(
      fixture.setParent(tagId, wrongTargetId),
      throwsArgumentError,
    );
    expect(await fixture.parentId(tagId), isNull);
  });

  test('rejects malformed Parent state instead of repairing it', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final tagId = await fixture.createTag('数学');
    await fixture.genericStore.setValue(
      recordId: tagId,
      propertyId: fixture.schema.parentProperty.id,
      value: 'malformed',
    );

    await expectLater(fixture.setParent(tagId, null), throwsStateError);
    final tag = await fixture.tag(tagId);
    expect(tag.values[fixture.schema.parentProperty.id], 'malformed');
  });

  test('rejects Parent index drift instead of repairing it', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final rootId = await fixture.createTag('root');
    final childId = await fixture.createTag('child');
    await fixture.setParent(childId, rootId);
    await fixture.database.customStatement(
      'UPDATE object_relation_edges SET position = 7 '
      'WHERE source_object_id = ? AND property_id = ?',
      <Object>[childId, fixture.schema.parentProperty.id],
    );

    await expectLater(fixture.setParent(childId, null), throwsStateError);
    expect(await fixture.parentId(childId), rootId);
    final edges = await fixture.objectStore.outgoingRelations(childId);
    final parentEdge = edges.singleWhere(
      (edge) => edge.propertyId == fixture.schema.parentProperty.id,
    );
    expect(parentEdge.position, 7);
  });

  test('rejects corrupted multiple Parent targets', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final childId = await fixture.createTag('child');
    final firstId = await fixture.createTag('first');
    final secondId = await fixture.createTag('second');
    final propertyId = fixture.schema.parentProperty.id;
    await fixture.genericStore.setValue(
      recordId: childId,
      propertyId: propertyId,
      value: <int>[firstId, secondId],
    );
    await fixture.objectStore.ensureRelationIndexSchema();
    await fixture.database.customStatement(
      'INSERT INTO object_relation_edges('
      'source_object_id, property_id, target_object_id, position) '
      'VALUES (?, ?, ?, 0), (?, ?, ?, 1)',
      <Object>[childId, propertyId, firstId, childId, propertyId, secondId],
    );

    await expectLater(fixture.setParent(childId, firstId), throwsStateError);
    final child = await fixture.tag(childId);
    final stored = ObjectRelationValue.fromJson(child.values[propertyId]);
    expect(stored.objectIds, <int>[firstId, secondId]);
  });

  test('accepts only canonical TagGroup targets', () async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final tagId = await fixture.createTag('数学');
    final groupId = await fixture.objectStore.createObject(
      objectTypeId: fixture.schema.tagGroupObjectType.id,
      title: '分野',
    );
    await fixture.setGroup(tagId, groupId);
    expect(await fixture.groupId(tagId), groupId);

    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final wrongGroupId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Wrong',
    );
    await expectLater(
      fixture.setGroup(tagId, wrongGroupId),
      throwsArgumentError,
    );
    expect(await fixture.groupId(tagId), groupId);
  });

  test(
    'keeps direct Object Tag assignments independent of ancestors',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.database.close);
      final rootId = await fixture.createTag('root');
      final childId = await fixture.createTag('child');
      await fixture.setParent(childId, rootId);
      final noteTypeId = await fixture.objectStore.createObjectType(
        workspaceId: fixture.workspaceId,
        name: 'Note',
      );
      final propertyId = await fixture.objectStore.createRelationProperty(
        objectTypeId: noteTypeId,
        name: 'Tags',
        targetObjectTypeId: fixture.schema.objectType.id,
        multiple: true,
      );
      final noteType = (await fixture.objectStore.getObjectType(noteTypeId))!;
      final property = noteType.properties.singleWhere(
        (candidate) => candidate.id == propertyId,
      );
      final noteId = await fixture.objectStore.createObject(
        objectTypeId: noteTypeId,
        title: 'Apple note',
      );
      await fixture.objectStore.setRelation(
        objectId: noteId,
        property: property,
        targetObjectIds: <int>[childId],
      );

      final notes = await fixture.objectStore.listObjects(noteTypeId);
      final note = notes.singleWhere((object) => object.id == noteId);
      final assigned = ObjectRelationValue.fromJson(note.values[propertyId]);
      expect(assigned.objectIds, <int>[childId]);
      expect(assigned.objectIds, isNot(contains(rootId)));
    },
  );
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
    genericStore: genericStore,
    objectStore: objectStore,
    bridge: bridge,
    schema: schema,
  );
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.bridge,
    required this.schema,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final TagObjectBridge bridge;
  final TagObjectSchema schema;

  Future<int> createTag(String title) {
    return objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: title,
    );
  }

  Future<void> setParent(int tagId, int? parentId) {
    return bridge.hierarchyIntegrity.setParent(
      workspaceId: workspaceId,
      tagObjectId: tagId,
      parentProperty: schema.parentProperty,
      parentTagObjectId: parentId,
    );
  }

  Future<void> setGroup(int tagId, int? groupId) {
    return bridge.hierarchyIntegrity.setGroup(
      workspaceId: workspaceId,
      tagObjectId: tagId,
      groupProperty: schema.groupProperty,
      tagGroupObjectId: groupId,
    );
  }

  Future<AppObject> tag(int tagId) async {
    final tags = await objectStore.listObjects(schema.objectType.id);
    return tags.singleWhere((object) => object.id == tagId);
  }

  Future<int?> parentId(int tagId) async {
    final object = await tag(tagId);
    final relation = ObjectRelationValue.fromJson(
      object.values[schema.parentProperty.id],
    );
    return relation.objectIds.isEmpty ? null : relation.objectIds.single;
  }

  Future<int?> groupId(int tagId) async {
    final object = await tag(tagId);
    final relation = ObjectRelationValue.fromJson(
      object.values[schema.groupProperty.id],
    );
    return relation.objectIds.isEmpty ? null : relation.objectIds.single;
  }
}
