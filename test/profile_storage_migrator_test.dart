import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/profile_storage_migrator.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Move rebases source-contained absolute paths and preserves external paths',
    () async {
      final source = await Directory.systemTemp.createTemp('vault_move_source_');
      final target = await Directory.systemTemp.createTemp('vault_move_target_');
      final external =
          await Directory.systemTemp.createTemp('vault_move_external_');
      addTearDown(() => source.delete(recursive: true));
      addTearDown(() => target.delete(recursive: true));
      addTearDown(() => external.delete(recursive: true));

      final sourcePhoto = File('${source.path}/photos/inside.jpg');
      final sourceAttachment =
          File('${source.path}/attachments/inside.pdf');
      final targetPhoto = File('${target.path}/photos/inside.jpg');
      final targetAttachment =
          File('${target.path}/attachments/inside.pdf');
      final externalPhoto = File('${external.path}/outside.jpg');
      final externalAttachment = File('${external.path}/outside.pdf');
      for (final file in [
        sourcePhoto,
        sourceAttachment,
        targetPhoto,
        targetAttachment,
        externalPhoto,
        externalAttachment,
      ]) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes([1, 2, 3]);
      }

      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        profileDirectoryPath: target.path,
      );
      addTearDown(database.close);
      final bookmarkId = await database.addBookmark(
        url: 'https://example.com',
        title: 'Example',
      );
      final internalPhotoId = await database.into(database.photos).insert(
            PhotosCompanion.insert(path: sourcePhoto.path),
          );
      final externalPhotoId = await database.into(database.photos).insert(
            PhotosCompanion.insert(path: externalPhoto.path),
          );
      final internalAttachmentId =
          await database.into(database.bookmarkAttachments).insert(
                BookmarkAttachmentsCompanion.insert(
                  bookmarkId: bookmarkId,
                  fileName: 'inside.pdf',
                  path: sourceAttachment.path,
                  kind: const Value('pdf'),
                  sizeBytes: const Value(3),
                  createdAt: DateTime(2026, 9, 7).toIso8601String(),
                ),
              );
      final externalAttachmentId =
          await database.into(database.bookmarkAttachments).insert(
                BookmarkAttachmentsCompanion.insert(
                  bookmarkId: bookmarkId,
                  fileName: 'outside.pdf',
                  path: externalAttachment.path,
                  kind: const Value('pdf'),
                  sizeBytes: const Value(3),
                  createdAt: DateTime(2026, 9, 7).toIso8601String(),
                ),
              );

      await const ProfileStorageMigrator().migratePhotos(
        database: database,
        photoDirectoryPath: '${target.path}/photos',
        previousProfileDirectoryPath: source.path,
        importExternalFiles: false,
      );

      final photos = {
        for (final row in await database.select(database.photos).get())
          row.id: row.path,
      };
      final attachments = {
        for (final row
            in await database.select(database.bookmarkAttachments).get())
          row.id: row.path,
      };

      expect(photos[internalPhotoId], 'photos/inside.jpg');
      expect(photos[externalPhotoId], externalPhoto.path);
      expect(attachments[internalAttachmentId], 'attachments/inside.pdf');
      expect(attachments[externalAttachmentId], externalAttachment.path);
      expect(
        await File('${target.path}/photos/${externalPhotoId}_outside.jpg')
            .exists(),
        isFalse,
      );
      expect(
        await File(
          '${target.path}/attachments/${externalAttachmentId}_outside.pdf',
        ).exists(),
        isFalse,
      );
    },
  );

  test('Move does not rewrite a source-contained path without a target copy',
      () async {
    final source = await Directory.systemTemp.createTemp('vault_move_source_');
    final target = await Directory.systemTemp.createTemp('vault_move_target_');
    addTearDown(() => source.delete(recursive: true));
    addTearDown(() => target.delete(recursive: true));

    final sourcePhoto = File('${source.path}/photos/missing-at-target.jpg');
    await sourcePhoto.parent.create(recursive: true);
    await sourcePhoto.writeAsBytes([1, 2, 3]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: target.path,
    );
    addTearDown(database.close);
    final photoId = await database.into(database.photos).insert(
          PhotosCompanion.insert(path: sourcePhoto.path),
        );

    await const ProfileStorageMigrator().migratePhotos(
      database: database,
      photoDirectoryPath: '${target.path}/photos',
      previousProfileDirectoryPath: source.path,
      importExternalFiles: false,
    );

    final photo = await (database.select(database.photos)
          ..where((row) => row.id.equals(photoId)))
        .getSingle();
    expect(photo.path, sourcePhoto.path);
    expect(
      await File('${target.path}/photos/${photoId}_missing-at-target.jpg')
          .exists(),
      isFalse,
    );
  });

  test('normal startup keeps legacy external import behavior', () async {
    final target = await Directory.systemTemp.createTemp('vault_startup_target_');
    final external =
        await Directory.systemTemp.createTemp('vault_startup_external_');
    addTearDown(() => target.delete(recursive: true));
    addTearDown(() => external.delete(recursive: true));

    final externalPhoto = File('${external.path}/legacy.jpg');
    final externalAttachment = File('${external.path}/legacy.pdf');
    await externalPhoto.writeAsBytes([1, 2, 3]);
    await externalAttachment.writeAsBytes([4, 5, 6]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: target.path,
    );
    addTearDown(database.close);
    final bookmarkId = await database.addBookmark(
      url: 'https://example.com/legacy',
      title: 'Legacy',
    );
    final photoId = await database.into(database.photos).insert(
          PhotosCompanion.insert(path: externalPhoto.path),
        );
    final attachmentId =
        await database.into(database.bookmarkAttachments).insert(
              BookmarkAttachmentsCompanion.insert(
                bookmarkId: bookmarkId,
                fileName: 'legacy.pdf',
                path: externalAttachment.path,
                kind: const Value('pdf'),
                sizeBytes: const Value(3),
                createdAt: DateTime(2026, 9, 7).toIso8601String(),
              ),
            );

    await const ProfileStorageMigrator().migratePhotos(
      database: database,
      photoDirectoryPath: '${target.path}/photos',
    );

    final photo = await (database.select(database.photos)
          ..where((row) => row.id.equals(photoId)))
        .getSingle();
    final attachment = await (database.select(database.bookmarkAttachments)
          ..where((row) => row.id.equals(attachmentId)))
        .getSingle();

    expect(photo.path, 'photos/${photoId}_legacy.jpg');
    expect(attachment.path, 'attachments/${attachmentId}_legacy.pdf');
    expect(
      await File('${target.path}/${photo.path}').readAsBytes(),
      [1, 2, 3],
    );
    expect(
      await File('${target.path}/${attachment.path}').readAsBytes(),
      [4, 5, 6],
    );
  });
}
