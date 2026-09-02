import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_config_service.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config context exposes current target and same-workspace ObjectTypes',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final otherWorkspaceId = await workspaceStore.createWorkspace(name: 'Other');
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = DatabaseCollectionConfigService(
      collectionStore: collectionStore,
      objectStore: objectStore,
    );

    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final placeTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    await objectStore.createObjectType(
      workspaceId: otherWorkspaceId,
      name: 'Foreign',
    );

    await service.save(
      databaseId: databaseId,
      workspaceId: workspaceId,
      targetObjectTypeId: placeTypeId,
    );

    final context = await service.load(databaseId);

    expect(context, isNotNull);
    expect(context!.targetObjectType.id, placeTypeId);
    expect(
      context.availableObjectTypes.map((type) => type.id).toSet(),
      containsAll(<int>{databaseId, placeTypeId}),
    );
    expect(context.availableObjectTypes.every(
      (type) => type.workspaceId == workspaceId,
    ), isTrue);
  });

  test('save reuses persisted validation for collection filter Properties',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseCollectionConfigService(
      collectionStore: DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      objectStore: objectStore,
    );

    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final targetId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final otherId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other',
    );
    final foreignPropertyId = await objectStore.createProperty(
      objectTypeId: otherId,
      name: 'Foreign',
      type: ObjectPropertyType.text,
    );

    await expectLater(
      service.save(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetId,
        collectionFilter: <ObjectFilterRule>[
          ObjectFilterRule(
            propertyId: foreignPropertyId,
            operator: ObjectFilterOperator.equals,
            value: 'x',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
