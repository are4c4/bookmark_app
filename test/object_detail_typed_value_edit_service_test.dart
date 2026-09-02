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
  test('typed detail Value mutations persist normalized values', () async {
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
      name: 'Entry',
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
      config: const <String, dynamic>{'options': <String>['Todo', 'Done']},
    );
    final multiId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
    );
    final dateId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Due',
      type: ObjectPropertyType.date,
    );
    final ratingId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Rating',
      type: ObjectPropertyType.rating,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Entry',
    );
    var content = (await loader.load(objectTypeId: typeId, objectId: objectId))!;
    ObjectPropertyDefinition property(int id) => content.objectType.properties
        .singleWhere((candidate) => candidate.id == id);

    content = await edits.setCheckbox(
      content: content,
      property: property(checkboxId),
      value: true,
    );
    content = await edits.setSelect(
      content: content,
      property: property(selectId),
      value: ' Done ',
    );
    content = await edits.setMultiSelect(
      content: content,
      property: property(multiId),
      values: const <String>[' alpha ', '', 'beta'],
    );
    content = await edits.setDate(
      content: content,
      property: property(dateId),
      value: ' 2026-09-02 ',
    );
    content = await edits.setRating(
      content: content,
      property: property(ratingId),
      value: 4,
    );

    expect(content.object.valueFor(checkboxId), isTrue);
    expect(content.object.valueFor(selectId), 'Done');
    expect(content.object.valueFor(multiId), <String>['alpha', 'beta']);
    expect(content.object.valueFor(dateId), '2026-09-02');
    expect(content.object.valueFor(ratingId), 4);
  });

  test('typed detail Value mutations reject mismatched or invalid inputs', () async {
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
      name: 'Entry',
    );
    final textId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final dateId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Due',
      type: ObjectPropertyType.date,
    );
    final ratingId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Rating',
      type: ObjectPropertyType.rating,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Entry',
    );
    final content = (await loader.load(objectTypeId: typeId, objectId: objectId))!;
    ObjectPropertyDefinition property(int id) => content.objectType.properties
        .singleWhere((candidate) => candidate.id == id);

    await expectLater(
      edits.setCheckbox(
        content: content,
        property: property(textId),
        value: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => edits.setDate(
        content: content,
        property: property(dateId),
        value: 'not-a-date',
      ),
      throwsArgumentError,
    );
    expect(
      () => edits.setRating(
        content: content,
        property: property(ratingId),
        value: 6,
      ),
      throwsRangeError,
    );
  });
}
