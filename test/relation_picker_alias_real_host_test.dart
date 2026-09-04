import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real Relation picker resolves alias and saves canonical Object id',
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
    final aliasStore = ObjectAliasStore(genericStore);
    final collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '本棚',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    final serreId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Jean-Pierre Serre',
    );
    await aliasStore.addAlias(objectId: serreId, alias: 'セール');
    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: bookTypeId,
      ),
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

    await tester.tap(find.text('数論講義').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Author').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'セール');
    await tester.pumpAndSettle();

    expect(find.text('Jean-Pierre Serre'), findsOneWidget);
    expect(find.text('別名: セール'), findsOneWidget);
    await tester.tap(find.text('Jean-Pierre Serre'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final book = (await objectStore.listObjects(bookTypeId))
        .singleWhere((object) => object.id == bookId);
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[serreId],
    );
  });
}
