import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page Relation editor composition preserves bidirectional lifecycle', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );

    final context = await services.relationEditor.load(
      workspaceId: workspaceId,
      sourceObjectId: bookId,
      property: pair.sourceProperty,
    );
    await services.relationEditor.save(
      context: context,
      selectedObjectIds: [personId],
    );

    final person = (await objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(person.values[pair.inverseProperty.id]).objectIds,
      [bookId],
    );
  });

  test('page Relation editor composition exposes missing targets without mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

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
      name: 'Targets',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final property =
        (await objectStore.getObjectType(sourceTypeId))!.properties.single;
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );
    const missingTargetId = 999999;
    await genericStore.setValue(
      recordId: sourceId,
      propertyId: property.id,
      value: const <String, dynamic>{'objectIds': [missingTargetId]},
    );

    final context = await services.relationEditor.load(
      workspaceId: workspaceId,
      sourceObjectId: sourceId,
      property: property,
    );
    final source = (await objectStore.listObjects(sourceTypeId)).single;

    expect(context.missingTargetObjectIds, [missingTargetId]);
    expect(
      ObjectRelationValue.fromJson(source.values[property.id]).objectIds,
      [missingTargetId],
    );
  });
}
