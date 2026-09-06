import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/database_view_property_type_migration_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/database_property_schema_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RelationSchemaEvolutionService _relationEvolution(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
) =>
    RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
        genericStore: genericStore,
      ),
    );

DatabaseViewPropertyTypeMigrationService _valueMigration(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
) =>
    DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );

Future<ObjectPropertyDefinition> _property(
  ObjectStore store,
  int objectTypeId,
  int propertyId,
) async =>
    (await store.getObjectType(objectTypeId))!
        .properties
        .singleWhere((property) => property.id == propertyId);

void main() {
  testWidgets('Relation Property dispatches to Relation schema editor',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final property = await _property(objectStore, sourceTypeId, relationId);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatabasePropertySchemaEditor(
                context: context,
                property: property,
                objectStore: objectStore,
                relationSchemaEvolution:
                    _relationEvolution(genericStore, objectStore),
                valueConversion:
                    DatabaseViewPropertyTypeConversionService(objectStore),
                valueMigration: _valueMigration(genericStore, objectStore),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Relation Propertyを編集'), findsOneWidget);
    expect(find.text('Value Propertyを編集'), findsNothing);
  });

  testWidgets('editable Value Property dispatches to Value schema editor',
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
      name: 'Memo',
      type: ObjectPropertyType.text,
    );
    final property = await _property(objectStore, typeId, propertyId);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: DatabasePropertySchemaEditButton(
              property: property,
              objectStore: objectStore,
              relationSchemaEvolution:
                  _relationEvolution(genericStore, objectStore),
              valueConversion:
                  DatabaseViewPropertyTypeConversionService(objectStore),
              valueMigration: _valueMigration(genericStore, objectStore),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(ValueKey('database-property-schema-edit-$propertyId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Value Propertyを編集'), findsOneWidget);
    expect(find.text('Relation Propertyを編集'), findsNothing);
  });

  testWidgets('computed Property exposes a disabled generic schema action',
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
      name: 'Formula-ish',
      type: ObjectPropertyType.formula,
      config: const <String, dynamic>{'expression': '1'},
    );
    final property = await _property(objectStore, typeId, propertyId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatabasePropertySchemaEditButton(
            property: property,
            objectStore: objectStore,
            relationSchemaEvolution:
                _relationEvolution(genericStore, objectStore),
            valueConversion:
                DatabaseViewPropertyTypeConversionService(objectStore),
            valueMigration: _valueMigration(genericStore, objectStore),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(
      find.byKey(ValueKey('database-property-schema-edit-$propertyId')),
    );
    expect(button.onPressed, isNull);
  });
}
