import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail loader combines stored values, Body and computed values', () async {
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

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final valueId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Value',
      type: ObjectPropertyType.number,
    );
    final formulaId = await computedStore.createFormulaProperty(
      objectTypeId: typeId,
      name: 'Double',
      expression: '{$valueId} * 2',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Example',
    );
    final type = (await objectStore.getObjectType(typeId))!;
    final valueProperty = type.properties.firstWhere((item) => item.id == valueId);
    final formulaProperty = type.properties.firstWhere((item) => item.id == formulaId);
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: valueProperty,
      value: 21,
    );
    await bodyStore.write(
      objectId: objectId,
      document: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'Body text'),
        ],
      ),
    );

    final content = await loader.load(objectTypeId: typeId, objectId: objectId);

    expect(content, isNotNull);
    expect(content!.object.title, 'Example');
    expect(content.valueFor(valueProperty), 21);
    expect(content.valueFor(formulaProperty), 42);
    expect(content.body.blocks.single.text, 'Body text');
  });

  test('detail loader returns null for missing Object', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final loader = ObjectDetailContentLoader(
      objectStore: objectStore,
      bodyStore: ObjectBodyStore(genericStore),
      computedStore: ObjectComputedValueStore(objectStore),
    );

    expect(
      await loader.load(objectTypeId: typeId, objectId: 999999),
      isNull,
    );
  });
}
