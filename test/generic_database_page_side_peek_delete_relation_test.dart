import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('side peek deletion detaches incoming Relations', (tester) async {
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
    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
      icon: '📚',
    );
    final authorPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Delete target',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Surviving book',
    );
    final bookType = (await objectStore.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties
        .singleWhere((property) => property.id == authorPropertyId);
    await services.relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[personId],
    );

    final definition = DatabaseDefinition(
      key: 'custom:$personTypeId',
      label: 'People',
      icon: Icons.people_outline,
      properties: const <DatabasePropertyDefinition>[],
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
          databaseId: personTypeId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete target').first);
    await tester.pumpAndSettle();
    expect(find.text('詳細'), findsOneWidget);

    await tester.tap(find.byTooltip('削除').last);
    await tester.pumpAndSettle();

    expect(await objectStore.listObjects(personTypeId), isEmpty);
    final survivingBook = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(
        survivingBook.valueFor(authorPropertyId),
      ).objectIds,
      isEmpty,
    );
    expect(find.text('詳細'), findsNothing);
  });
}
