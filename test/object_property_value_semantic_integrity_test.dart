import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted Relation semantics cannot be bypassed by forged Value metadata',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final bookId = await store.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await store.createObject(
      objectTypeId: personTypeId,
      title: 'Author',
    );
    final stored = (await store.getObjectType(bookTypeId))!.properties.single;
    final forged = ObjectPropertyDefinition(
      id: stored.id,
      objectTypeId: stored.objectTypeId,
      name: stored.name,
      type: ObjectPropertyType.text,
      sortOrder: stored.sortOrder,
    );

    await expectLater(
      store.setPropertyValue(
        objectId: bookId,
        property: forged,
        value: ObjectRelationValue(objectIds: <int>[personId]).toJson(
          multiple: false,
        ),
      ),
      throwsArgumentError,
    );

    expect(await store.outgoingRelations(bookId), isEmpty);
    final book = (await store.listObjects(bookTypeId)).single;
    expect(book.values.containsKey(stored.id), isFalse);
  });

  test('persisted Value type rejects forged caller type metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final typeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    await store.createProperty(
      objectTypeId: typeId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final objectId = await store.createObject(
      objectTypeId: typeId,
      title: 'Book',
    );
    final stored = (await store.getObjectType(typeId))!.properties.single;
    final forged = ObjectPropertyDefinition(
      id: stored.id,
      objectTypeId: stored.objectTypeId,
      name: stored.name,
      type: ObjectPropertyType.text,
      sortOrder: stored.sortOrder,
    );

    await expectLater(
      store.setPropertyValue(
        objectId: objectId,
        property: forged,
        value: 'not a number',
      ),
      throwsArgumentError,
    );

    final object = (await store.listObjects(typeId)).single;
    expect(object.values.containsKey(stored.id), isFalse);
  });

  test('computed Properties reject direct stored value writes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));
    final computed = ObjectComputedValueStore(store);

    final typeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final amountId = await store.createProperty(
      objectTypeId: typeId,
      name: 'Amount',
      type: ObjectPropertyType.number,
    );
    final formulaId = await computed.createFormulaProperty(
      objectTypeId: typeId,
      name: 'Double',
      expression: '{$amountId} * 2',
    );
    final objectId = await store.createObject(
      objectTypeId: typeId,
      title: 'Book',
    );
    final formula = (await store.getObjectType(typeId))!
        .properties
        .singleWhere((property) => property.id == formulaId);

    await expectLater(
      store.setPropertyValue(
        objectId: objectId,
        property: formula,
        value: 42,
      ),
      throwsArgumentError,
    );

    final object = (await store.listObjects(typeId)).single;
    expect(object.values.containsKey(formulaId), isFalse);
  });
}
