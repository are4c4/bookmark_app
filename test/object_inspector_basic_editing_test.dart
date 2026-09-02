import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Object inspector edits custom title and simple Value properties',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final notePropertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    final ratingPropertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final type = (await objectStore.getObjectType(typeId))!;
    final noteProperty = type.properties
        .singleWhere((property) => property.id == notePropertyId);
    final ratingProperty = type.properties
        .singleWhere((property) => property.id == ratingPropertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Before',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: noteProperty,
      value: 'old note',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: ratingProperty,
      value: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-title-edit-field')),
      'After',
    );
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('After'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('edit-object-value-$notePropertyId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('object-value-edit-field-$notePropertyId')),
      'new note',
    );
    await tester.tap(
      find.byKey(ValueKey('object-value-edit-save-$notePropertyId')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('edit-object-value-$ratingPropertyId')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('object-value-edit-field-$ratingPropertyId')),
      '4.5',
    );
    await tester.tap(
      find.byKey(ValueKey('object-value-edit-save-$ratingPropertyId')),
    );
    await tester.pumpAndSettle();

    final object = (await objectStore.listObjects(typeId)).single;
    expect(object.title, 'After');
    expect(object.values[notePropertyId], 'new note');
    expect(object.values[ratingPropertyId], 4.5);
  });
}
