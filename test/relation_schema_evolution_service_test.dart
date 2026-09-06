import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late RelationSchemaEvolutionService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    service = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
    );
  });

  Future<({
    int sourceTypeId,
    int targetTypeId,
    ObjectPropertyDefinition property,
  })> createRelation({bool multiple = true}) async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
      multiple: multiple,
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .single;
    return (
      sourceTypeId: sourceTypeId,
      targetTypeId: targetTypeId,
      property: property,
    );
  }

  List<(int, int, int, int)> edgeShape(List<ObjectRelationEdge> edges) => edges
      .map(
        (edge) => (
          edge.sourceObjectId,
          edge.propertyId,
          edge.targetObjectId,
          edge.position,
        ),
      )
      .toList(growable: false);

  test('target change fails closed and preserves value, edge and backlink', () async {
    final setup = await createRelation();
    final otherTargetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other target',
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: setup.sourceTypeId,
      title: 'Source object',
    );
    final targetId = await objectStore.createObject(
      objectTypeId: setup.targetTypeId,
      title: 'Target object',
    );
    await objectStore.setRelation(
      objectId: sourceId,
      property: setup.property,
      targetObjectIds: <int>[targetId],
    );

    await expectLater(
      service.changeRelationSchema(
        property: setup.property,
        targetObjectTypeId: otherTargetTypeId,
        multiple: true,
      ),
      throwsStateError,
    );

    final storedProperty = (await objectStore.getObjectType(setup.sourceTypeId))!
        .properties
        .single;
    final source = (await objectStore.listObjects(setup.sourceTypeId)).single;
    expect(storedProperty.targetObjectTypeId, setup.targetTypeId);
    expect(storedProperty.allowsMultipleRelations, isTrue);
    expect(
      ObjectRelationValue.fromJson(source.values[setup.property.id]).objectIds,
      <int>[targetId],
    );
    expect(
      (await objectStore.outgoingRelations(sourceId))
          .map((edge) => edge.targetObjectId)
          .toList(),
      <int>[targetId],
    );
    expect(
      (await objectStore.backlinks(targetId))
          .map((edge) => edge.sourceObjectId)
          .toList(),
      <int>[sourceId],
    );
  });

  test('multi to single requires explicit choice and preserves old schema', () async {
    final setup = await createRelation();
    final sourceId = await objectStore.createObject(
      objectTypeId: setup.sourceTypeId,
      title: 'Source object',
    );
    final firstTargetId = await objectStore.createObject(
      objectTypeId: setup.targetTypeId,
      title: 'First',
    );
    final secondTargetId = await objectStore.createObject(
      objectTypeId: setup.targetTypeId,
      title: 'Second',
    );
    await objectStore.setRelation(
      objectId: sourceId,
      property: setup.property,
      targetObjectIds: <int>[firstTargetId, secondTargetId],
    );

    await expectLater(
      service.changeRelationSchema(
        property: setup.property,
        targetObjectTypeId: setup.targetTypeId,
        multiple: false,
      ),
      throwsStateError,
    );

    final storedProperty = (await objectStore.getObjectType(setup.sourceTypeId))!
        .properties
        .single;
    final source = (await objectStore.listObjects(setup.sourceTypeId)).single;
    expect(storedProperty.allowsMultipleRelations, isTrue);
    expect(
      ObjectRelationValue.fromJson(source.values[setup.property.id]).objectIds,
      <int>[firstTargetId, secondTargetId],
    );
    expect(await objectStore.outgoingRelations(sourceId), hasLength(2));
  });

  test('single to multi preserves stored target and normalized edges', () async {
    final setup = await createRelation(multiple: false);
    final sourceId = await objectStore.createObject(
      objectTypeId: setup.sourceTypeId,
      title: 'Source object',
    );
    final targetId = await objectStore.createObject(
      objectTypeId: setup.targetTypeId,
      title: 'Target object',
    );
    await objectStore.setRelation(
      objectId: sourceId,
      property: setup.property,
      targetObjectIds: <int>[targetId],
    );
    final edgesBefore = edgeShape(await objectStore.outgoingRelations(sourceId));

    final changed = await service.changeRelationSchema(
      property: setup.property,
      targetObjectTypeId: setup.targetTypeId,
      multiple: true,
    );

    final source = (await objectStore.listObjects(setup.sourceTypeId)).single;
    final edgesAfter = edgeShape(await objectStore.outgoingRelations(sourceId));
    expect(changed.allowsMultipleRelations, isTrue);
    expect(
      ObjectRelationValue.fromJson(source.values[setup.property.id]).objectIds,
      <int>[targetId],
    );
    expect(edgesAfter, edgesBefore);
    expect(await objectStore.backlinks(targetId), hasLength(1));
  });

  test('empty target change updates only the Relation schema', () async {
    final setup = await createRelation();
    final otherTargetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other target',
    );

    final changed = await service.changeRelationSchema(
      property: setup.property,
      targetObjectTypeId: otherTargetTypeId,
      multiple: true,
    );

    expect(changed.targetObjectTypeId, otherTargetTypeId);
    expect(await objectStore.listObjects(setup.sourceTypeId), isEmpty);
  });
}
