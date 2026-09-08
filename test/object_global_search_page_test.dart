import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
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

  testWidgets(
      'replays active query after focused refresh from another Search service instance',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objects = ObjectStore(store);
    final pageSearch = ObjectGlobalSearchService(store);
    final producerSearch = ObjectGlobalSearchService(store);

    final noteTypeId = await objects.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
      icon: '📝',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
          searchService: pageSearch,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'backgroundvisible');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('一致するオブジェクトがありません'), findsOneWidget);

    final objectId = await objects.createObject(
      objectTypeId: noteTypeId,
      title: 'BackgroundVisible Token',
    );
    await producerSearch.refreshObject(objectId);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-$objectId')),
      findsOneWidget,
      reason:
          'a Search-local projection change from another service instance must replay the active query',
    );
    expect(find.text('BackgroundVisible Token'), findsOneWidget);
  });

  testWidgets(
      'refreshes opened Object and Relation-label dependents after detail return',
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
    final authorPropertyId = await objects.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final bookType = (await objects.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties.firstWhere(
      (property) => property.id == authorPropertyId,
    );
    final authorId = await objects.createObject(
      objectTypeId: personTypeId,
      title: 'LegacyReturnLabel',
    );
    final bookId = await objects.createObject(
      objectTypeId: bookTypeId,
      title: 'Dependent source book',
    );
    await objects.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[authorId],
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

    await tester.enterText(find.byType(TextField), 'legacyreturn');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-$authorId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('object-global-search-result-$bookId')),
      findsOneWidget,
      reason: 'source Object must initially match through relation_labels',
    );

    await tester.tap(
      find.byKey(ValueKey('object-global-search-result-$authorId')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ObjectInspectorPage), findsOneWidget);

    await objects.renameObject(authorId, 'CurrentReturnLabel');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('一致するオブジェクトがありません'), findsOneWidget);
    expect(
      find.byKey(ValueKey('object-global-search-result-$bookId')),
      findsNothing,
      reason:
          'return refresh must remove the stale denormalized relation label',
    );

    await tester.enterText(find.byType(TextField), 'currentreturn');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-$authorId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('object-global-search-result-$bookId')),
      findsOneWidget,
      reason: 'dependent relation label must be reindexed with the new title',
    );
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
