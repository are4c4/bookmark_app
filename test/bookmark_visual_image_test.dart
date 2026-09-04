import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_visual_resolver.dart';
import 'package:bookmark_app/widgets/bookmark_visual_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a resolved managed local image', (tester) async {
    final directory = await Directory.systemTemp.createTemp('visual_widget_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/preview.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: BookmarkLifecycleStore(database),
      workspaceId: workspaceId,
    );
    final bookmark = BookmarkItem(
      id: 1,
      url: 'https://example.com/article',
      title: 'Article',
      createdAt: DateTime(2026, 9, 4),
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkVisualImage(
            repository: repository,
            bookmark: bookmark,
            width: 80,
            height: 40,
            placeholder: const Text('placeholder'),
            resolveSource: (_) async => BookmarkVisualSource(
              kind: BookmarkVisualSourceKind.managedRepresentative,
              value: file.path,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect(find.text('placeholder'), findsNothing);

    // Dispose FileImage listeners before test teardown. The test intentionally
    // has no legacy remote thumbnail, so decode failure cannot start HTTP I/O.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shows the supplied placeholder when no visual resolves',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: BookmarkLifecycleStore(database),
      workspaceId: workspaceId,
    );
    final bookmark = BookmarkItem(
      id: 2,
      url: 'https://example.net/article',
      title: 'Article',
      createdAt: DateTime(2026, 9, 4),
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookmarkVisualImage(
          repository: repository,
          bookmark: bookmark,
          placeholder: const Text('placeholder'),
          resolveSource: (_) async => null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('placeholder'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
