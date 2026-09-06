import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/database_view_property_type_migration_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/value_property_schema_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int objectTypeId,
  int propertyId,
) async =>
    (await store.getObjectType(objectTypeId))!
        .properties
        .singleWhere((property) => property.id == propertyId);

DatabaseViewPropertyTypeMigrationService _migration(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
) =>
    DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

void main() {
  testWidgets('URL to Text confirms impact then preserves value and Property id',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final propertyId = await objectStore.createProperty(
      objectTypeId: await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Entry',
      ),
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final property = await _property(
      objectStore,
      (await genericStore.listAllDatabases(workspaceId)).single.id,
      propertyId,
    );
    final objectId = await objectStore.createObject(
      objectTypeId: property.objectTypeId,
      title: 'Entry',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: 'https://example.com',
    );

    ObjectPropertyDefinition? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showValuePropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  conversion:
                      DatabaseViewPropertyTypeConversionService(objectStore),
                  migration: _migration(genericStore, objectStore),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Value Propertyを編集'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('value-property-schema-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();

    expect(find.textContaining('URL  →  Text'), findsOneWidget);
    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, propertyId);
    expect(result!.type, ObjectPropertyType.text);
    expect(
      (await objectStore.listObjects(property.objectTypeId))
          .single
          .values[propertyId],
      'https://example.com',
    );
  });

  testWidgets('MultiSelect to Select requires an explicit value per ambiguous Object',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Labels',
      type: ObjectPropertyType.multiSelect,
      config: const <String, dynamic>{
        'options': <String>['alpha', 'beta'],
      },
    );
    final property = await _property(objectStore, typeId, propertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Ambiguous',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: <String>['alpha', 'beta'],
    );

    ObjectPropertyDefinition? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showValuePropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  conversion:
                      DatabaseViewPropertyTypeConversionService(objectStore),
                  migration: _migration(genericStore, objectStore),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('value-property-schema-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();

    final confirmFinder =
        find.byKey(const ValueKey('property-type-conversion-confirm'));
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);
    await tester.tap(
      find.byKey(ValueKey('property-type-choice-$objectId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('beta').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.type, ObjectPropertyType.select);
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      'beta',
    );
  });

  testWidgets('migration-required conversion is surfaced but cannot be applied',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Text',
      type: ObjectPropertyType.text,
    );
    final property = await _property(objectStore, typeId, propertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Entry',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: property,
      value: '12',
    );

    ObjectPropertyDefinition? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showValuePropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  conversion:
                      DatabaseViewPropertyTypeConversionService(objectStore),
                  migration: _migration(genericStore, objectStore),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('value-property-schema-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-type-conversion-confirm')),
    );
    expect(confirm.onPressed, isNull);
    expect(find.textContaining('値の移行方針が必要'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(
      (await _property(objectStore, typeId, propertyId)).type,
      ObjectPropertyType.text,
    );
    expect(
      (await objectStore.listObjects(typeId)).single.values[propertyId],
      '12',
    );
  });

  testWidgets('system Value Property fails closed before showing edit UI',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'value-schema-test',
      name: 'System',
      icon: '⚙️',
    );
    final property = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Text',
      type: ObjectPropertyType.text,
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('host'))));
    final context = tester.element(find.text('host'));
    await expectLater(
      showValuePropertySchemaEditor(
        context: context,
        property: property,
        objectStore: objectStore,
        conversion: DatabaseViewPropertyTypeConversionService(objectStore),
        migration: _migration(genericStore, objectStore),
      ),
      throwsStateError,
    );
    expect(find.text('Value Propertyを編集'), findsNothing);
  });
}
