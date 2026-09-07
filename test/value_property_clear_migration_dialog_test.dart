import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/database_view_property_type_migration_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/value_property_schema_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('migration-required type change needs a second destructive confirmation',
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
    final property = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
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
                  migration: DatabaseViewPropertyTypeMigrationService(
                    genericStore: genericStore,
                    objectStore: objectStore,
                  ),
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

    final normalConfirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-type-conversion-confirm')),
    );
    expect(normalConfirm.onPressed, isNull);
    expect(find.textContaining('値の移行方針が必要'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('property-type-clear-values-path')));
    await tester.pumpAndSettle();
    final destructiveConfirmFinder =
        find.byKey(const ValueKey('property-type-clear-confirm'));
    expect(
      tester.widget<FilledButton>(destructiveConfirmFinder).onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('property-type-clear-confirm-checkbox')),
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(destructiveConfirmFinder).onPressed,
      isNotNull,
    );
    await tester.tap(destructiveConfirmFinder);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, propertyId);
    expect(result!.type, ObjectPropertyType.number);
    expect(
      (await objectStore.listObjects(typeId)).single.values.containsKey(propertyId),
      isFalse,
    );
  });
}
