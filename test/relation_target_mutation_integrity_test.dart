import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mutation selection accepts a healthy stored/indexed Relation', () async {
    final fixture = await _fixture(multiple: true);
    addTearDown(fixture.database.close);

    final context = await fixture.service.selectionForMutation(
      workspaceId: fixture.workspaceId,
      sourceObjectId: fixture.sourceId,
      property: fixture.property,
    );

    expect(context.selectedObjectIds, <int>[fixture.firstTargetId]);
    expect(context.missingTargetObjectIds, isEmpty);
    expect(context.hasCardinalityViolation, isFalse);
  });

  test('mutation selection rejects edge position drift without repairing it',
      () async {
    final fixture = await _fixture(multiple: true);
    addTearDown(fixture.database.close);

    await fixture.database.customStatement(
      'UPDATE object_relation_edges SET position = 7 '
      'WHERE source_object_id = ? AND property_id = ?',
      <Object>[fixture.sourceId, fixture.property.id],
    );

    await expectLater(
      fixture.service.selectionForMutation(
        workspaceId: fixture.workspaceId,
        sourceObjectId: fixture.sourceId,
        property: fixture.property,
      ),
      throwsStateError,
    );

    final edges = (await fixture.objectStore.outgoingRelations(fixture.sourceId))
        .where((edge) => edge.propertyId == fixture.property.id)
        .toList(growable: false);
    expect(edges, hasLength(1));
    expect(edges.single.targetObjectId, fixture.firstTargetId);
    expect(edges.single.position, 7);
    final persisted = (await fixture.genericStore.listRecords(fixture.sourceTypeId))
        .singleWhere((record) => record.id == fixture.sourceId);
    expect(persisted.values[fixture.property.id], <int>[fixture.firstTargetId]);
  });

  test('mutation selection rejects a wrong-type target without repair', () async {
    final fixture = await _fixture(multiple: true);
    addTearDown(fixture.database.close);
    final otherTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Other',
    );
    final wrongTargetId = await fixture.objectStore.createObject(
      objectTypeId: otherTypeId,
      title: 'Wrong target',
    );

    await fixture.genericStore.setValue(
      recordId: fixture.sourceId,
      propertyId: fixture.property.id,
      value: <int>[fixture.firstTargetId, wrongTargetId],
    );
    await fixture.database.customStatement(
      '''INSERT INTO object_relation_edges(
           source_object_id, property_id, target_object_id, position
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[
        fixture.sourceId,
        fixture.property.id,
        wrongTargetId,
        1,
      ],
    );

    await expectLater(
      fixture.service.selectionForMutation(
        workspaceId: fixture.workspaceId,
        sourceObjectId: fixture.sourceId,
        property: fixture.property,
      ),
      throwsStateError,
    );

    final edges = (await fixture.objectStore.outgoingRelations(fixture.sourceId))
        .where((edge) => edge.propertyId == fixture.property.id)
        .toList(growable: false);
    expect(
      edges.map((edge) => edge.targetObjectId),
      <int>[fixture.firstTargetId, wrongTargetId],
    );
    final persisted = (await fixture.genericStore.listRecords(fixture.sourceTypeId))
        .singleWhere((record) => record.id == fixture.sourceId);
    expect(
      persisted.values[fixture.property.id],
      <int>[fixture.firstTargetId, wrongTargetId],
    );
  });

  test('mutation selection rejects single-Relation cardinality corruption',
      () async {
    final fixture = await _fixture(multiple: false);
    addTearDown(fixture.database.close);
    final secondTargetId = await fixture.objectStore.createObject(
      objectTypeId: fixture.targetTypeId,
      title: 'Second',
    );

    await fixture.genericStore.setValue(
      recordId: fixture.sourceId,
      propertyId: fixture.property.id,
      value: <int>[fixture.firstTargetId, secondTargetId],
    );
    await fixture.database.customStatement(
      '''INSERT INTO object_relation_edges(
           source_object_id, property_id, target_object_id, position
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[
        fixture.sourceId,
        fixture.property.id,
        secondTargetId,
        1,
      ],
    );

    final diagnostic = await fixture.service.selectionFor(
      workspaceId: fixture.workspaceId,
      sourceObjectId: fixture.sourceId,
      property: fixture.property,
    );
    expect(
      diagnostic.selectedObjectIds,
      <int>[fixture.firstTargetId, secondTargetId],
    );
    expect(diagnostic.hasCardinalityViolation, isTrue);

    await expectLater(
      fixture.service.selectionForMutation(
        workspaceId: fixture.workspaceId,
        sourceObjectId: fixture.sourceId,
        property: fixture.property,
      ),
      throwsStateError,
    );
  });
}

Future<_Fixture> _fixture({required bool multiple}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final sourceTypeId = await objectStore.createObjectType(
    workspaceId: workspaceId,
    name: 'Source',
  );
  final targetTypeId = await objectStore.createObjectType(
    workspaceId: workspaceId,
    name: 'Target',
  );
  final propertyId = await objectStore.createRelationProperty(
    objectTypeId: sourceTypeId,
    name: 'Relation',
    targetObjectTypeId: targetTypeId,
    multiple: multiple,
  );
  final property = (await objectStore.getObjectType(sourceTypeId))!
      .properties
      .singleWhere((candidate) => candidate.id == propertyId);
  final sourceId = await objectStore.createObject(
    objectTypeId: sourceTypeId,
    title: 'Source',
  );
  final firstTargetId = await objectStore.createObject(
    objectTypeId: targetTypeId,
    title: 'First',
  );
  await objectStore.setRelation(
    objectId: sourceId,
    property: property,
    targetObjectIds: <int>[firstTargetId],
  );

  return _Fixture(
    database: database,
    workspaceId: workspaceId,
    genericStore: genericStore,
    objectStore: objectStore,
    service: RelationTargetService(objectStore),
    sourceTypeId: sourceTypeId,
    targetTypeId: targetTypeId,
    property: property,
    sourceId: sourceId,
    firstTargetId: firstTargetId,
  );
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
    required this.service,
    required this.sourceTypeId,
    required this.targetTypeId,
    required this.property,
    required this.sourceId,
    required this.firstTargetId,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final RelationTargetService service;
  final int sourceTypeId;
  final int targetTypeId;
  final ObjectPropertyDefinition property;
  final int sourceId;
  final int firstTargetId;
}
