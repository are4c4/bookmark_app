import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/data/database_view_property_type_migration_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/widgets/database_property_schema_management_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SchemaServices {
  _SchemaServices({
    required this.genericStore,
    required this.objectStore,
  }) {
    final viewStore = DatabaseViewStore(genericStore.database);
    propertySchema = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: viewStore,
    );
    relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    relationSchemaEvolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: relationMutations,
    );
    conversion = DatabaseViewPropertyTypeConversionService(objectStore);
    migration = DatabaseViewPropertyTypeMigrationService(
      genericStore: genericStore,
      objectStore: objectStore,
    );
  }

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  late final DatabaseViewPropertySchemaService propertySchema;
  late final RelationMutationService relationMutations;
  late final RelationSchemaEvolutionService relationSchemaEvolution;
  late final DatabaseViewPropertyTypeConversionService conversion;
  late final DatabaseViewPropertyTypeMigrationService migration;
}

Future<void> _open(
  WidgetTester tester, {
  required int objectTypeId,
  required _SchemaServices services,
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDatabasePropertySchemaManagementDialog(
              context: context,
              objectTypeId: objectTypeId,
              objectStore: services.objectStore,
              propertySchema: services.propertySchema,
              relationSchemaEvolution: services.relationSchemaEvolution,
              valueConversion: services.conversion,
              valueMigration: services.migration,
              relationMutations: services.relationMutations,
              onChanged: onChanged,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rename and safe type edit preserve the Property id', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = _SchemaServices(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Value',
      type: ObjectPropertyType.text,
    );

    await _open(tester, objectTypeId: typeId, services: services);

    await tester.tap(
      find.byKey(ValueKey('property-schema-rename-$propertyId')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ValueKey('property-schema-rename-input-$propertyId')),
      'Amount',
    );
    await tester.tap(
      find.byKey(ValueKey('property-schema-rename-submit-$propertyId')),
    );
    await tester.pumpAndSettle();

    final renamed = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((property) => property.id == propertyId);
    expect(renamed.name, 'Amount');
    expect(find.text('Amount'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('database-property-schema-edit-$propertyId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('value-property-schema-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('property-type-conversion-confirm')),
    );
    await tester.pumpAndSettle();

    final changed = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((property) => property.id == propertyId);
    expect(changed.id, propertyId);
    expect(changed.name, 'Amount');
    expect(changed.type, ObjectPropertyType.number);
  });

  testWidgets('ordinary delete prunes ObjectType defaults before schema removal',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaults = ObjectTypeDefaultsStore(genericStore);
    final services = _SchemaServices(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Temporary',
      type: ObjectPropertyType.text,
    );
    await defaults.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: [propertyId],
        propertyOrder: [propertyId],
      ),
    );

    await _open(tester, objectTypeId: typeId, services: services);
    await tester.tap(
      find.byKey(ValueKey('property-schema-delete-$propertyId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      (await objectStore.getObjectType(typeId))!
          .properties
          .where((property) => property.id == propertyId),
      isEmpty,
    );
    final persistedDefaults = await defaults.read(typeId);
    expect(persistedDefaults?.visiblePropertyIds, isEmpty);
    expect(persistedDefaults?.propertyOrder, isEmpty);
  });

  testWidgets('empty Relation delete uses the safe Relation lifecycle',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = _SchemaServices(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Author',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );

    await _open(tester, objectTypeId: sourceTypeId, services: services);
    await tester.tap(
      find.byKey(ValueKey('property-schema-delete-$relationId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      (await objectStore.getObjectType(sourceTypeId))!
          .properties
          .where((property) => property.id == relationId),
      isEmpty,
    );
  });

  testWidgets('system ObjectType is read-only in schema management',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final services = _SchemaServices(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final systemTypeId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: 'System-like',
      icon: 'S',
    );
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS system_object_types (
        workspace_id INTEGER NOT NULL,
        system_key TEXT NOT NULL,
        object_type_id INTEGER NOT NULL UNIQUE,
        PRIMARY KEY(workspace_id, system_key)
      )
    ''');
    await database.customStatement(
      'INSERT INTO system_object_types(workspace_id, system_key, object_type_id) VALUES (?, ?, ?)',
      [workspaceId, 'test-system', systemTypeId],
    );

    await _open(tester, objectTypeId: systemTypeId, services: services);

    expect(
      find.text('システムObjectTypeのプロパティはここでは変更できません。'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
