import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_value_promotion_execution_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_value_promotion.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ObjectPropertyDefinition> propertyById(
  ObjectStore store,
  int objectTypeId,
  int propertyId,
) async {
  final type = (await store.getObjectType(objectTypeId))!;
  return type.properties.singleWhere((property) => property.id == propertyId);
}

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late ObjectValuePromotionExecutionService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    service = ObjectValuePromotionExecutionService(
      objectStore: objectStore,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
        genericStore: genericStore,
      ),
    );
  });

  tearDown(() async => database.close());

  test('promotion creates Relation and preserves source Value by default', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Author text',
      type: ObjectPropertyType.text,
    );
    final property = await propertyById(objectStore, sourceTypeId, propertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    await objectStore.setPropertyValue(
      objectId: sourceId,
      property: property,
      value: 'Alice',
    );

    final result = await service.execute(
      plan: const ObjectValuePromotionPlanner().plan(
        sourceProperty: property,
        sourceValue: 'Alice',
        targetObjectTypeId: targetTypeId,
        targetObjectTitle: 'Alice',
        relationPropertyName: 'Author',
      ),
      sourceObjectId: sourceId,
    );

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[propertyId], 'Alice');
    expect(result.createdTargetObject, isTrue);
    expect(result.createdRelationProperty, isTrue);
    expect(
      ObjectRelationValue.fromJson(source.values[result.relationProperty.id])
          .objectIds,
      [result.targetObject.id],
    );
  });

  test('stale plan fails before target creation', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Author text',
      type: ObjectPropertyType.text,
    );
    final property = await propertyById(objectStore, sourceTypeId, propertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    await objectStore.setPropertyValue(
      objectId: sourceId,
      property: property,
      value: 'Changed',
    );

    final plan = const ObjectValuePromotionPlanner().plan(
      sourceProperty: property,
      sourceValue: 'Original',
      targetObjectTypeId: targetTypeId,
      targetObjectTitle: 'Original',
      relationPropertyName: 'Author',
    );

    await expectLater(
      service.execute(plan: plan, sourceObjectId: sourceId),
      throwsStateError,
    );
    expect(await objectStore.listObjects(targetTypeId), isEmpty);
  });
}
