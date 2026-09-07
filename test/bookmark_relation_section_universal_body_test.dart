import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_object_link_read_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/widgets/bookmark_relation_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mirrored Bookmark detail edits the canonical universal Body',
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
    final bookmarkId = await repository.create(
      url: 'https://example.com/bookmark-body',
      title: 'Bookmark Body',
      inbox: true,
    );
    final bookmark = (await repository.watchAll().first)
        .singleWhere((item) => item.id == bookmarkId);

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);
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
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('bookmark-object-body-$bookmarkId')),
      findsOneWidget,
    );
    expect(find.text('Body'), findsOneWidget);
    final field = find.byKey(const ValueKey('body-text-body'));
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Edited Bookmark note');
    await tester.pumpAndSettle();

    final body = await bodyStore.read(objectId);
    expect(body.blocks.single.text, 'Edited Bookmark note');
  });

  testWidgets('unmirrored Bookmark detail keeps legacy content fail-soft',
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
    await tester.pumpAndSettle();

    expect(find.text('関連ブックマーク'), findsOneWidget);
    expect(
      find.byKey(ValueKey('bookmark-object-body-$bookmarkId')),
      findsNothing,
    );
  });
}
