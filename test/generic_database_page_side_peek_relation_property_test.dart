import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'side peek shared Relation row renders canonical target Object chip',
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
    final authorId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Canonical Author',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Relation target',
    );
    final bookType = (await objectStore.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties
        .singleWhere((property) => property.id == authorPropertyId);
    await services.relationMutations.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[authorId],
    );

    final definition = DatabaseDefinition(
      key: 'custom:$bookTypeId',
      label: 'Books',
      icon: Icons.book_outlined,
      properties: <DatabasePropertyDefinition>[
        DatabasePropertyDefinition(
          key: 'p:$authorPropertyId',
          label: 'Author',
          type: DatabasePropertyType.text,
          icon: Icons.link,
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
          databaseId: bookTypeId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relation target').first);
    await tester.pumpAndSettle();

    expect(find.byType(ObjectDetailPropertyView), findsOneWidget);
    expect(find.text('Author'), findsWidgets);
    final relationChip = find.byType(ActionChip);
    expect(relationChip, findsOneWidget);
    expect(
      find.descendant(
        of: relationChip,
        matching: find.text('Canonical Author'),
      ),
      findsOneWidget,
    );
    expect(find.text('$authorId'), findsNothing);
  });
}
