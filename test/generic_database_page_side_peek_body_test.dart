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
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_editor_section.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generic Database side peek edits the canonical Object Body',
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
    final bodyStore = ObjectBodyStore(genericStore);
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Notes',
      icon: '📝',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: databaseId,
      title: 'Side peek Body note',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'body',
            type: ObjectBodyBlockType.paragraph,
            text: 'Initial side peek notes',
          ),
        ],
      ),
    );

    await DatabaseViewStore(database).createView(
      workspaceId: workspaceId,
      definition: DatabaseDefinition(
        key: 'custom:$databaseId',
        label: 'Notes',
        icon: Icons.note_outlined,
        properties: const <DatabasePropertyDefinition>[],
        defaultLayout: 'list',
        supportedLayouts: const <String>['list'],
      ),
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
          databaseId: databaseId,
          onDatabaseChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Side peek Body note').first);
    await tester.pumpAndSettle();

    expect(find.text('詳細'), findsOneWidget);
    final bodyHost = find.byKey(
      ValueKey('side-peek-object-body-$objectId'),
    );
    expect(bodyHost, findsOneWidget);
    expect(
      find.descendant(
        of: bodyHost,
        matching: find.byType(ObjectBodyEditorSection),
      ),
      findsOneWidget,
    );

    final bodyField = find.descendant(
      of: bodyHost,
      matching: find.byKey(const ValueKey('body-text-body')),
    );
    expect(bodyField, findsOneWidget);
    await tester.enterText(bodyField, 'Edited in side peek');
    await tester.pumpAndSettle();

    final persisted = await bodyStore.read(objectId);
    expect(persisted.blocks.single.text, 'Edited in side peek');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
