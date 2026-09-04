import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('side peek renders persisted rich Body through shared document view',
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
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Body target',
    );
    await ObjectBodyStore(genericStore).write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'paragraph-1',
            type: 'paragraph',
            text: 'Shared body paragraph',
          ),
          ObjectBodyBlock(
            id: 'future-1',
            type: 'futureWidget',
            attributes: <String, dynamic>{'payload': 'keep-me'},
          ),
        ],
      ),
    );

    final definition = DatabaseDefinition(
      key: 'custom:$objectTypeId',
      label: 'Notes',
      icon: Icons.notes_outlined,
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
          databaseId: objectTypeId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Body target').first);
    await tester.pumpAndSettle();

    expect(find.text('詳細'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.byType(ObjectBodyDocumentView), findsOneWidget);
    expect(find.text('Shared body paragraph'), findsOneWidget);
    expect(find.text('Unsupported block: futureWidget'), findsOneWidget);
  });
}
