import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real generic Collection manages the displayed target ObjectType schema',
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
      final collectionStore = DatabaseCollectionStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );

      final plantTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Plant',
        icon: '🪴',
      );
      final scorePropertyId = await objectStore.createProperty(
        objectTypeId: plantTypeId,
        name: 'Score',
        type: ObjectPropertyType.number,
      );
      await objectStore.createObject(
        objectTypeId: plantTypeId,
        title: 'Monstera',
      );

      final dashboardDatabaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Plant Dashboard',
        icon: '📊',
      );
      final dashboardPropertyId = await objectStore.createProperty(
        objectTypeId: dashboardDatabaseId,
        name: 'Dashboard only',
        type: ObjectPropertyType.text,
      );
      await collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: dashboardDatabaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: plantTypeId,
        ),
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: dashboardDatabaseId,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monstera'), findsOneWidget);
      await tester.tap(find.byTooltip('データベース設定'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('database-manage-properties-menu-item')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('database-manage-properties-menu-item')),
      );
      await tester.pumpAndSettle();

      expect(find.text('プロパティ設定'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Dashboard only'), findsNothing);

      await tester.tap(
        find.byKey(ValueKey('property-schema-rename-$scorePropertyId')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('property-schema-rename-input-$scorePropertyId')),
        'Priority',
      );
      await tester.tap(
        find.byKey(ValueKey('property-schema-rename-submit-$scorePropertyId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Priority'), findsOneWidget);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      final plantType = await objectStore.getObjectType(plantTypeId);
      expect(
        plantType!.properties
            .singleWhere((property) => property.id == scorePropertyId)
            .name,
        'Priority',
      );
      final dashboardType = await objectStore.getObjectType(dashboardDatabaseId);
      expect(
        dashboardType!.properties
            .singleWhere((property) => property.id == dashboardPropertyId)
            .name,
        'Dashboard only',
      );
    },
  );
}
