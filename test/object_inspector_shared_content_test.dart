import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ObjectInspector renders persisted Body and ObjectType visibility defaults', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final shownId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Shown',
      type: ObjectPropertyType.text,
    );
    final hiddenByDefaultsId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Hidden by defaults',
      type: ObjectPropertyType.text,
    );
    final type = (await objectStore.getObjectType(typeId))!;
    final shown = type.properties.singleWhere((property) => property.id == shownId);
    final hiddenByDefaults = type.properties
        .singleWhere((property) => property.id == hiddenByDefaultsId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Shared inspector',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: shown,
      value: 'visible value',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: hiddenByDefaults,
      value: 'should not render',
    );
    await bodyStore.write(
      objectId: objectId,
      document: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'Body paragraph'),
        ],
      ),
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[shownId],
        propertyOrder: <int>[shownId],
        openMode: ObjectOpenMode.fullPage,
      ),
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

    expect(find.text('Shared inspector'), findsOneWidget);
    expect(find.text('Shown'), findsOneWidget);
    expect(find.text('visible value'), findsOneWidget);
    expect(find.text('Hidden by defaults'), findsNothing);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Body paragraph'), findsOneWidget);
  });
}
