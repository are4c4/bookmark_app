import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_object_link_read_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_editor_section.dart';
import 'package:bookmark_app/widgets/bookmark_relation_section.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 20,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

void _closeDatabaseAfterUnmount(
  WidgetTester tester,
  AppDatabase database,
) {
  addTearDown(() async {
    // BookmarkRelationSection owns a Drift-backed StreamBuilder. Dispose the
    // widget subscription before closing its database so a failed assertion
    // cannot leave the full-suite runner waiting on a live stream.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
}

Future<void> _mirrorLegacyObjectsOnce({
  required AppDatabase database,
  required int workspaceId,
}) async {
  final genericStore = GenericDatabaseStore(database);
  final objectStore = ObjectStore(genericStore);
  final systemObjects = SystemObjectStore(
    database: database,
    objectStore: objectStore,
  );
  final tagBridge = TagObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemObjects,
  );
  await CoreObjectBridge(
    database: database,
    objectStore: objectStore,
    systemObjectStore: systemObjects,
    tagBridge: tagBridge,
  ).syncAll(workspaceId);
}

void main() {
  testWidgets('mirrored Bookmark detail edits the canonical universal Body',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
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
    final bookmarkId = await repository.create(
      url: 'https://example.com/bookmark-body',
      title: 'Bookmark Body',
      inbox: true,
    );
    final bookmark = (await repository.watchAll().first)
        .singleWhere((item) => item.id == bookmarkId);

    // This regression needs a real Bookmark -> Object mirror, but not the
    // app-level live watcher. CoreObjectBridge performs the canonical one-shot
    // mirror without leaving a long-lived Rx subscription in the widget test.
    await _mirrorLegacyObjectsOnce(
      database: database,
      workspaceId: workspaceId,
    );
    final objectId = await BookmarkObjectLinkReadStore(database)
        .objectIdForBookmark(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    expect(objectId, isNotNull);

    final genericStore = GenericDatabaseStore(database);
    final bodyStore = ObjectBodyStore(genericStore);
    await bodyStore.write(
      objectId: objectId!,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'body',
            type: ObjectBodyBlockType.paragraph,
            text: 'Initial Bookmark note',
          ),
        ],
      ),
    );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookmarkRelationSection(
              repository: repository,
              bookmark: bookmark,
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('body-text-body'));
    await _pumpUntil(tester, field);
    expect(
      find.byKey(ValueKey('bookmark-object-body-$bookmarkId')),
      findsOneWidget,
    );
    expect(find.text('Body'), findsOneWidget);

    await tester.enterText(field, 'Edited Bookmark note');
    await tester.pump(const Duration(milliseconds: 100));

    final body = await bodyStore.read(objectId);
    expect(body.blocks.single.text, 'Edited Bookmark note');
  });

  testWidgets('corrupt universal Body stays fail closed', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
      icon: '👤',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Corrupt Body host',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    await bodyStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(object_id)
         DO UPDATE SET document_json = excluded.document_json''',
      <Object?>[objectId, '[]'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyEditorSection(
            store: genericStore,
            objectStore: objectStore,
            objectId: objectId,
            workspaceId: workspaceId,
          ),
        ),
      ),
    );

    final error = find.byKey(const ValueKey('body-load-error'));
    await _pumpUntil(tester, error);
    expect(find.byKey(const ValueKey('body-load-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('body-empty-insert')), findsNothing);

    final row = await database.customSelect(
      'SELECT document_json FROM object_bodies WHERE object_id = ?',
      variables: [Variable<int>(objectId)],
    ).getSingle();
    expect(row.read<String>('document_json'), '[]');
  });

  testWidgets('unmirrored Bookmark detail keeps legacy content fail-soft',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
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
    final bookmarkId = await repository.create(
      url: 'https://example.com/unmirrored-bookmark-body',
      title: 'Legacy only Bookmark',
      inbox: true,
    );
    final bookmark = (await repository.watchAll().first)
        .singleWhere((item) => item.id == bookmarkId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkRelationSection(
            repository: repository,
            bookmark: bookmark,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('関連ブックマーク'), findsOneWidget);
    expect(
      find.byKey(ValueKey('bookmark-object-body-$bookmarkId')),
      findsNothing,
    );
  });
}
