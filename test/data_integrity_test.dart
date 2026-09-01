import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_attachment_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/full_text_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkLifecycleStore lifecycleStore;
  late BookmarkRepository repository;
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_app_integrity_',
    );
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: tempDirectory.path,
    );
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      profileDirectoryPath: tempDirectory.path,
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<BookmarkItem> createBookmark() async {
    final id = await repository.create(
      url: 'https://example.com/article',
      title: 'Example article',
    );
    return (await repository.watchAll().first)
        .firstWhere((bookmark) => bookmark.id == id);
  }

  test('FTS initializes on a fresh current-schema database', () async {
    final bookmark = await createBookmark();
    final search = FullTextSearchRepository(repository);

    await search.rebuild();
    final hits = await search.search('Example');

    expect(hits.map((hit) => hit.bookmarkId), contains(bookmark.id));
  });

  test('archive and unarchive keep storage and reading state consistent',
      () async {
    final bookmark = await createBookmark();

    await repository.archive(bookmark);
    final archived = await repository.watchArchive().first;
    expect(archived.map((item) => item.id), contains(bookmark.id));

    await repository.unarchive(bookmark);
    final row = await (database.select(database.bookmarks)
          ..where((item) => item.id.equals(bookmark.id)))
        .getSingle();

    expect(row.storageState, 'active');
    expect(row.status, row.readingStatus);
    expect(
      (await repository.watchArchive().first)
          .any((item) => item.id == bookmark.id),
      isFalse,
    );
  });

  test('deleting a photo clears profile-photo references and managed files',
      () async {
    final photoFile = File('${tempDirectory.path}/photos/photo.jpg');
    await photoFile.create(recursive: true);
    await photoFile.writeAsBytes([1, 2, 3]);
    final backupFile = File('${photoFile.path}.bookmark_original');
    await backupFile.writeAsBytes([1, 2, 3]);

    final photoId = await repository.addPhoto(path: photoFile.path);
    final storedPhoto = await (database.select(database.photos)
          ..where((item) => item.id.equals(photoId)))
        .getSingle();
    expect(storedPhoto.path, 'photos/photo.jpg');

    final personId = await repository.createPerson('Author');
    await database.updatePerson(
      personId,
      'Author',
      null,
      profilePhotoId: photoId,
      updateProfilePhoto: true,
    );
    final photo = (await repository.watchPhotos().first)
        .firstWhere((item) => item.id == photoId);

    await repository.deletePhoto(photo);

    final person = await (database.select(database.people)
          ..where((item) => item.id.equals(personId)))
        .getSingle();
    expect(person.profilePhotoId, isNull);
    expect(await photoFile.exists(), isFalse);
    expect(await backupFile.exists(), isFalse);
  });

  test('permanent bookmark deletion removes managed attachment files',
      () async {
    final bookmark = await createBookmark();
    final attachmentFile =
        File('${tempDirectory.path}/attachments/document.pdf');
    await attachmentFile.create(recursive: true);
    await attachmentFile.writeAsBytes([1, 2, 3]);

    final store = BookmarkAttachmentStore(database);
    final attachmentId = await store.add(
      bookmarkId: bookmark.id,
      fileName: 'document.pdf',
      path: attachmentFile.path,
      kind: 'pdf',
      sizeBytes: 3,
    );
    final storedAttachment =
        await (database.select(database.bookmarkAttachments)
              ..where((item) => item.id.equals(attachmentId)))
            .getSingle();
    expect(storedAttachment.path, 'attachments/document.pdf');

    await repository.permanentDelete(bookmark);

    expect(await attachmentFile.exists(), isFalse);
    expect(await store.listForBookmark(bookmark.id), isEmpty);
    expect(
      await (database.select(database.bookmarks)
            ..where((item) => item.id.equals(bookmark.id)))
          .getSingleOrNull(),
      isNull,
    );
  });
  test('saved views persist relation and tag matching filters', () async {
    final personId = await repository.createPerson('Author');
    final photoFile = File('${tempDirectory.path}/photos/cover.jpg');
    await photoFile.create(recursive: true);
    await photoFile.writeAsBytes([1]);
    final photoId = await repository.addPhoto(path: photoFile.path);

    final viewId = await repository.createSavedView(
      name: 'Author photos',
      layoutType: 'table',
      tagMatchMode: 'and',
      includeDescendants: false,
      personFilterId: personId,
      photoFilterId: photoId,
    );
    final view = await (database.select(database.savedViews)
          ..where((item) => item.id.equals(viewId)))
        .getSingle();

    expect(view.tagMatchMode, 'and');
    expect(view.includeDescendants, isFalse);
    expect(view.personFilterId, personId);
    expect(view.photoFilterId, photoId);
  });

}
