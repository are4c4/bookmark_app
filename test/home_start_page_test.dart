import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/home_start_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows canonical recently changed Objects with ObjectType context',
    (tester) async {
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
        title: 'Local fields',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeStartPage(store: store, workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('最近のオブジェクト'), findsOneWidget);
      expect(find.text('Local fields'), findsOneWidget);
      expect(find.textContaining('Papers'), findsOneWidget);
      expect(
        find.byKey(ValueKey('home-recent-object-$objectId')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a useful empty state without inventing Home-only data', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近更新したオブジェクトはありません。'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Favorites'), findsNothing);
    expect(find.text('Pinned Databases'), findsNothing);
  });
}
