import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_attachment_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/attachment_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late BookmarkRepository repository;
  var databaseClosed = false;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_attachment_managed_copy_',
    );
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: tempDirectory.path,
    );
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      profileDirectoryPath: tempDirectory.path,
    );
    databaseClosed = false;
  });

  tearDown(() async {
    if (!databaseClosed) {
      await database.close();
    }
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('bookmark attachment import reuses portable Vault managed storage',
      () async {
    final bookmarkId = await repository.create(
      url: 'https://example.com/managed-attachment',
      title: 'Managed attachment',
    );
    final source = File('${tempDirectory.path}/incoming/research.pdf');
    await source.create(recursive: true);
    await source.writeAsBytes(const <int>[1, 2, 3, 4]);
    final store = BookmarkAttachmentStore(database);

    final added = await const AttachmentStorageService().importPathsForBookmark(
      bookmarkId: bookmarkId,
      profileDirectoryPath: tempDirectory.path,
      store: store,
      sourcePaths: <String>[source.path],
    );

    expect(added, hasLength(1));
    expect(added.single.path, startsWith('${tempDirectory.path}/attachments/'));
    expect(File(added.single.path).existsSync(), isTrue);
    expect(await source.readAsBytes(), const <int>[1, 2, 3, 4]);

    final stored = await database.select(database.bookmarkAttachments).getSingle();
    expect(stored.path, startsWith('attachments/'));
    expect(stored.path.startsWith('/'), isFalse);
  });

  test('database persistence failure rolls back only the new managed copy',
      () async {
    final source = File('${tempDirectory.path}/incoming/failure.pdf');
    await source.create(recursive: true);
    await source.writeAsBytes(const <int>[9, 8, 7]);
    final store = BookmarkAttachmentStore(database);
    await database.close();
    databaseClosed = true;

    await expectLater(
      const AttachmentStorageService().importPathsForBookmark(
        bookmarkId: 1,
        profileDirectoryPath: tempDirectory.path,
        store: store,
        sourcePaths: <String>[source.path],
      ),
      throwsA(anything),
    );

    expect(await source.readAsBytes(), const <int>[9, 8, 7]);
    final attachments = Directory('${tempDirectory.path}/attachments');
    expect(attachments.existsSync(), isTrue);
    expect(await attachments.list().toList(), isEmpty);
  });
}
