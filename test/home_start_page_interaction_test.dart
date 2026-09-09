import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/home_start_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({GenericDatabaseStore store, int workspaceId, int objectId})>
_createRecentFixture(
  WidgetTester tester, {
  String title = 'Keyboard recent',
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final workspaceId = await WorkspaceStore(database).initialize();
  final store = GenericDatabaseStore(database);
  final objectStore = ObjectStore(store);
  final typeId = await objectStore.createObjectType(
    workspaceId: workspaceId,
    name: 'Papers',
    icon: '📄',
  );
  final objectId = await objectStore.createObject(
    objectTypeId: typeId,
    title: title,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: HomeStartPage(store: store, workspaceId: workspaceId),
    ),
  );
  await tester.pumpAndSettle();

  return (store: store, workspaceId: workspaceId, objectId: objectId);
}

void main() {
  testWidgets(
    'autofocuses first Recent item and Enter opens shared Inspector',
    (tester) async {
      final fixture = await _createRecentFixture(tester);
      final recentFinder = find.byKey(
        ValueKey('home-recent-object-${fixture.objectId}'),
      );

      expect(tester.widget<ListTile>(recentFinder).autofocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(ObjectInspectorPage), findsOneWidget);
    },
  );

  testWidgets(
    'Space activates the focused Recent item through the same route',
    (tester) async {
      final fixture = await _createRecentFixture(tester, title: 'Space recent');
      final recentFinder = find.byKey(
        ValueKey('home-recent-object-${fixture.objectId}'),
      );

      expect(tester.widget<ListTile>(recentFinder).autofocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byType(ObjectInspectorPage), findsOneWidget);
    },
  );

  testWidgets(
    'Recent focus order follows visible order and keeps touch semantics',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Notes',
        icon: '📝',
      );
      final olderId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Older',
      );
      final newerId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Newer',
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-01 10:00:00' WHERE id = ?",
        [olderId],
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-02 10:00:00' WHERE id = ?",
        [newerId],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: HomeStartPage(store: store, workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();

      final newerFinder = find.byKey(ValueKey('home-recent-object-$newerId'));
      final olderFinder = find.byKey(ValueKey('home-recent-object-$olderId'));
      final newerOrder = tester.widget<FocusTraversalOrder>(
        find
            .ancestor(
              of: newerFinder,
              matching: find.byType(FocusTraversalOrder),
            )
            .first,
      );
      final olderOrder = tester.widget<FocusTraversalOrder>(
        find
            .ancestor(
              of: olderFinder,
              matching: find.byType(FocusTraversalOrder),
            )
            .first,
      );

      expect((newerOrder.order as NumericFocusOrder).order, 0);
      expect((olderOrder.order as NumericFocusOrder).order, 1);
      expect(tester.getSize(newerFinder).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(newerFinder).flagsCollection.isButton, isTrue);

      await tester.tap(olderFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ObjectInspectorPage), findsOneWidget);
    },
  );

  testWidgets('empty Home tolerates keyboard traversal without a focus trap', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(find.text('最近更新したオブジェクトはありません。'), findsOneWidget);
    expect(find.byType(ObjectInspectorPage), findsNothing);
  });
}
