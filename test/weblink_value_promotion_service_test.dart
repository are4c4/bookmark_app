import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/object_value_promotion_execution_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/weblink_value_promotion_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL promotion reuses Weblink and preserves source URL', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final executor = ObjectValuePromotionExecutionService(
      objectStore: objectStore,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      ),
    );
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final service = WeblinkValuePromotionService(
      weblinks: weblinks,
      executor: executor,
    );

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final urlPropertyId = await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final sourceType = (await objectStore.getObjectType(sourceTypeId))!;
    final urlProperty = sourceType.properties
        .singleWhere((property) => property.id == urlPropertyId);
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    await objectStore.setPropertyValue(
      objectId: sourceId,
      property: urlProperty,
      value: 'https://example.com/path',
    );

    final first = await service.promote(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      sourceProperty: urlProperty,
      url: 'https://example.com/path',
    );
    final second = await service.promote(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      sourceProperty: urlProperty,
      url: 'https://example.com/path',
    );

    expect(second.targetObject.id, first.targetObject.id);
    final source = (await objectStore.listObjects(sourceTypeId)).single;
    expect(source.values[urlPropertyId], 'https://example.com/path');
    expect(
      ObjectRelationValue.fromJson(source.values[first.relationProperty.id])
          .objectIds,
      [first.targetObject.id],
    );
  });
}
