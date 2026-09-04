import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('side peek shared Property row keeps computed values read-only',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final computedStore = ObjectComputedValueStore(objectStore);
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Scores',
      icon: '🧮',
    );
    final valuePropertyId = await objectStore.createProperty(
      objectTypeId: databaseId,
      name: 'Score',
      type: ObjectPropertyType.number,
    );
    final formulaPropertyId = await computedStore.createFormulaProperty(
      objectTypeId: databaseId,
      name: 'Double',
      expression: '{$valuePropertyId} * 2',
    );
    final objectType = (await objectStore.getObjectType(databaseId))!;
    final valueProperty = objectType.properties
        .singleWhere((property) => property.id == valuePropertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Computed target',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: valueProperty,
      value: 3,
    );

    final definition = DatabaseDefinition(
      key: 'custom:$databaseId',
      label: 'Scores',
      icon: Icons.calculate_outlined,
      properties: [
        DatabasePropertyDefinition(
          key: 'p:$valuePropertyId',
          label: 'Score',
          type: DatabasePropertyType.number,
          icon: Icons.numbers,
        ),
        DatabasePropertyDefinition(
          key: 'p:$formulaPropertyId',
          label: 'Double',
          type: DatabasePropertyType.number,
          icon: Icons.functions,
        ),
      ],
      defaultLayout: 'list',
      supportedLayouts: const <String>['list'],
    );
    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Side View',
      layoutType: 'list',
      settings: const <String, dynamic>{'openMode': 'sidePeek'},
    );

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GenericDatabasePage(
          repository: repository,
          databaseId: databaseId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Computed target').first);
    await tester.pumpAndSettle();

    expect(find.byType(ObjectDetailPropertyView), findsNWidgets(2));
    expect(find.text('Double'), findsWidgets);
    expect(find.text('6'), findsWidgets);

    await tester.tap(find.text('6').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
