import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkRepository repository;
  late ObjectStore objectStore;
  late DatabaseViewStore viewStore;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    objectStore = ObjectStore(GenericDatabaseStore(database));
    viewStore = DatabaseViewStore(database);
  });

  tearDown(() => database.close());

  DatabaseDefinition definitionFor(int databaseId) => DatabaseDefinition(
        key: 'custom:$databaseId',
        label: 'Notes',
        icon: Icons.note_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'gallery',
        supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
      );

  Future<void> pumpPage(WidgetTester tester, int databaseId) async {
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
  }

  Future<void> setMode(
    WidgetTester tester,
    int viewId,
    String label,
  ) async {
    await tester.tap(find.byKey(ValueKey('database-view-menu-$viewId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Objectの開き方').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> closeCenterPeek(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(ObjectInspectorPage))).pop();
    await tester.pumpAndSettle();
  }

  testWidgets(
      'real View menu center peek routes Gallery and Table without stale side peek',
      (tester) async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Route target',
    );
    final definition = definitionFor(databaseId);
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Gallery',
      layoutType: 'gallery',
    );
    await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Table',
      layoutType: 'table',
    );
    final views = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    );
    final gallery = views.singleWhere((view) => view.name == 'Gallery');
    final table = views.singleWhere((view) => view.name == 'Table');

    await pumpPage(tester, databaseId);

    await setMode(tester, gallery.id, 'センターピーク');
    await tester.tap(find.text('Route target').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('詳細'), findsNothing);
    await closeCenterPeek(tester);

    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    await setMode(tester, table.id, 'センターピーク');
    await tester.tap(find.text('Route target').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('詳細'), findsNothing);
    await closeCenterPeek(tester);

    await setMode(tester, table.id, 'サイドピーク');
    await tester.tap(find.text('Route target').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('詳細'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route target').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('詳細'), findsNothing);
  });
}
