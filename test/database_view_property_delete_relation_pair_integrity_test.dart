import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_property_delete_impact_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete impact surfaces a zero-value bidirectional inverse Property',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );

    final impact = await service.inspectDelete(
      objectTypeId: bookTypeId,
      propertyId: pair.sourceProperty.id,
    );

    expect(impact.hasStoredValues, isFalse);
    expect(impact.isReferencedByViews, isFalse);
    expect(impact.hasPairedRelationImpact, isTrue);
    expect(impact.pairedRelationProperty?.id, pair.inverseProperty.id);
    expect(impact.pairedRelationProperty?.name, 'Books');
  });

  test('delete impact fails closed on corrupt bidirectional metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DatabaseViewPropertySchemaService(
      objectStore: objectStore,
      genericStore: genericStore,
      viewStore: DatabaseViewStore(database),
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final stored = (await genericStore.listProperties(sourceTypeId))
        .singleWhere((property) => property.id == propertyId);
    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: stored.id,
        databaseId: stored.databaseId,
        name: stored.name,
        type: stored.type,
        config: <String, dynamic>{
          ...stored.config,
          'bidirectional': true,
          'inversePropertyId': 999999,
        },
        sortOrder: stored.sortOrder,
      ),
    );

    await expectLater(
      service.inspectDelete(
        objectTypeId: sourceTypeId,
        propertyId: propertyId,
      ),
      throwsStateError,
    );
  });

  testWidgets('paired Relation impact keeps delete confirmation disabled',
      (tester) async {
    const source = ObjectPropertyDefinition(
      id: 1,
      objectTypeId: 10,
      name: 'Authors',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 0,
      config: <String, dynamic>{
        'targetObjectTypeId': 20,
        'multiple': true,
        'bidirectional': true,
        'inversePropertyId': 2,
      },
    );
    const inverse = ObjectPropertyDefinition(
      id: 2,
      objectTypeId: 20,
      name: 'Books',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 0,
      config: <String, dynamic>{
        'targetObjectTypeId': 10,
        'multiple': true,
        'bidirectional': true,
        'inversePropertyId': 1,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectPropertyDeleteImpactDialog(
            impact: ObjectPropertyDeleteImpact(
              property: source,
              objectsWithStoredValue: 0,
              viewReferences: <DatabaseViewPropertyReference>[],
              pairedRelationProperty: inverse,
            ),
          ),
        ),
      ),
    );

    expect(find.text('双方向Relationの相手Property'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-delete-confirm')),
          )
          .onPressed,
      isNull,
    );
  });
}
