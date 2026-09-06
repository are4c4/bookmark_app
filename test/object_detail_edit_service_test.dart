import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_detail_edit_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail edits title and Value Property then reloads', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final computedStore = ObjectComputedValueStore(objectStore);
    final loader = ObjectDetailContentLoader(
      objectStore: objectStore,
      bodyStore: bodyStore,
      computedStore: computedStore,
    );
    final edits = ObjectDetailEditService(
      objectStore: objectStore,
      bodyStore: bodyStore,
      loader: loader,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.text,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Before',
    );
    var content = (await loader.load(objectTypeId: typeId, objectId: objectId))!;
    final property = content.objectType.properties
        .singleWhere((candidate) => candidate.id == propertyId);

    content = await edits.rename(content: content, title: 'After');
    content = await edits.setValue(
      content: content,
      property: property,
      value: 'doing',
    );

    expect(content.object.title, 'After');
    expect(content.object.valueFor(propertyId), 'doing');
  });

  test('detail Value editing rejects Relation and Computed properties', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final loader = ObjectDetailContentLoader(
      objectStore: objectStore,
      bodyStore: bodyStore,
      computedStore: ObjectComputedValueStore(objectStore),
    );
    final edits = ObjectDetailEditService(
      objectStore: objectStore,
      bodyStore: bodyStore,
      loader: loader,
    );

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final relationId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Related',
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{'targetObjectTypeId': typeId, 'multiple': true},
    );
    final formulaId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Computed',
      type: ObjectPropertyType.formula,
      config: const <String, dynamic>{'expression': '1'},
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Item',
    );
    final content = (await loader.load(objectTypeId: typeId, objectId: objectId))!;
    final relation = content.objectType.properties
        .singleWhere((candidate) => candidate.id == relationId);
    final formula = content.objectType.properties
        .singleWhere((candidate) => candidate.id == formulaId);

    await expectLater(
      edits.setValue(content: content, property: relation, value: null),
      throwsArgumentError,
    );
    await expectLater(
      edits.setValue(content: content, property: formula, value: 1),
      throwsArgumentError,
    );
  });
}
