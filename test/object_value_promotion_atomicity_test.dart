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

void main() {
  test('late source clear failure rolls back target Relation and index writes',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    final service = ObjectValuePromotionExecutionService(
      objectStore: objectStore,
      relationMutations: mutations,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final sourcePropertyId = await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Author text',
      type: ObjectPropertyType.text,
    );
    final sourceProperty = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == sourcePropertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book',
    );
    await objectStore.setPropertyValue(
      objectId: sourceId,
      property: sourceProperty,
      value: 'Alice',
    );

    await database.customStatement('''
      CREATE TRIGGER fail_value_promotion_source_clear
      BEFORE UPDATE OF value_json ON generic_values
      WHEN OLD.record_id = $sourceId
        AND OLD.property_id = $sourcePropertyId
        AND NEW.value_json = 'null'
      BEGIN
        SELECT RAISE(ABORT, 'forced promotion source clear failure');
      END
    ''');

    final plan = const ObjectValuePromotionPlanner().plan(
      sourceProperty: sourceProperty,
      sourceValue: 'Alice',
      targetObjectTypeId: targetTypeId,
      targetObjectTitle: 'Alice',
      relationPropertyName: 'Author',
      sourceDisposition: ObjectValuePromotionSourceDisposition.clearAfterLink,
    );

    await expectLater(
      service.execute(
        plan: plan,
        sourceObjectId: sourceId,
        destructiveSourceClearConfirmed: true,
      ),
      throwsA(anything),
    );

    final sourceType = (await objectStore.getObjectType(sourceTypeId))!;
    expect(sourceType.properties, hasLength(1));
    expect(sourceType.properties.single.id, sourcePropertyId);
    expect(await objectStore.listObjects(targetTypeId), isEmpty);

    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[sourcePropertyId], 'Alice');
    expect(await objectStore.outgoingRelations(sourceId), isEmpty);
  });
}
