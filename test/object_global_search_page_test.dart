import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/object_global_search_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('searches canonical Objects across ObjectTypes and opens inspector',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objects = ObjectStore(store);

    final personTypeId = await objects.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final bookTypeId = await objects.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
      icon: '📚',
    );
    await objects.createObject(
      objectTypeId: personTypeId,
      title: '夏目漱石',
    );
    final bookId = await objects.createObject(
      objectTypeId: bookTypeId,
      title: 'Kokoro Search Token',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('オブジェクトを横断検索'), findsOneWidget);
    expect(find.textContaining('ブックマークを横断検索'), findsNothing);

    await tester.enterText(find.byType(TextField), 'kokoro');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Kokoro Search Token'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('object-global-search-result-$bookId')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ObjectInspectorPage), findsOneWidget);
    expect(find.text('Kokoro Search Token'), findsWidgets);
  });

  testWidgets('shows Object-specific empty-result language', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missingtoken');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('一致するオブジェクトがありません'), findsOneWidget);
    expect(find.textContaining('一致するブックマーク'), findsNothing);
  });
}
