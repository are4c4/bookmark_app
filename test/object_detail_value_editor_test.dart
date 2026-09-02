import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_detail_edit_service.dart';
import 'package:bookmark_app/data/object_detail_value_editor.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('describes editable Value kinds and keeps Relation unsupported', () async {
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
    final editor = ObjectDetailValueEditor(
      ObjectDetailEditService(
        objectStore: objectStore,
        bodyStore: bodyStore,
        loader: loader,
      ),
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final selectId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{'options': <String>['todo', 'done']},
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: typeId,
      name: 'Related',
      targetObjectTypeId: typeId,
    );
    final type = (await objectStore.getObjectType(typeId))!;
    final select = type.properties.singleWhere((p) => p.id == selectId);
    final relation = type.properties.singleWhere((p) => p.id == relationId);

    expect(editor.describe(select).kind, ObjectDetailValueEditorKind.select);
    expect(editor.describe(select).options, ['todo', 'done']);
    expect(editor.describe(relation).isEditable, isFalse);
  });

  test('dispatches typed submissions through shared mutation service', () async {
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
    final editor = ObjectDetailValueEditor(
      ObjectDetailEditService(
        objectStore: objectStore,
        bodyStore: bodyStore,
        loader: loader,
      ),
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Item',
    );
    final checkboxId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Done',
      type: ObjectPropertyType.checkbox,
    );
    final selectId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.select,
      config: const <String, dynamic>{'options': <String>['todo', 'done']},
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'A',
    );
    var content = (await loader.load(objectTypeId: typeId, objectId: objectId))!;
    final checkbox = content.objectType.properties.singleWhere((p) => p.id == checkboxId);
    final select = content.objectType.properties.singleWhere((p) => p.id == selectId);

    content = await editor.submit(
      content: content,
      property: checkbox,
      value: true,
    );
    content = await editor.submit(
      content: content,
      property: select,
      value: 'done',
    );

    expect(content.object.valueFor(checkboxId), isTrue);
    expect(content.object.valueFor(selectId), 'done');
    expect(
      () => editor.submit(content: content, property: select, value: 'other'),
      throwsArgumentError,
    );
  });
}
